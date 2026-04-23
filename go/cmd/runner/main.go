// Runner sidecar — POST /run (Basic Auth), GET /healthz, GET /ready, GET /metrics.
// Executes loop.sh via exec.CommandContext. Mutex enforces one run at a time.
// Parses token counts from Claude --output-format=stream-json stdout.
// Calls POST /api/agent_runs/:id/complete on Rails after loop exits.
package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const port = ":8080"

// runRequest is the JSON body for POST /run.
type runRequest struct {
	AgentRunID string `json:"agent_run_id"`
	Script     string `json:"script"` // path to loop.sh, defaults to ./loop.sh
}

// testRequest is the JSON body for POST /test.
type testRequest struct {
	Spec string `json:"spec"` // optional: specific spec file to run
}

// testResponse is the JSON body returned by POST /test.
type testResponse struct {
	ExitCode int    `json:"exit_code"`
	Output   string `json:"output"`
}

// completePayload is sent to Rails POST /api/agent_runs/:id/complete.
type completePayload struct {
	ExitCode     int `json:"exit_code"`
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

// streamUsage matches the usage block in Claude stream-json output.
type streamUsage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

type streamLine struct {
	Type  string      `json:"type"`
	Usage streamUsage `json:"usage"`
}

// parseTokens scans Claude --output-format=stream-json stdout for token counts.
// Returns the last usage block found (final totals).
func parseTokens(output []byte) (inputTokens, outputTokens int) {
	scanner := bufio.NewScanner(bytes.NewReader(output))
	for scanner.Scan() {
		var line streamLine
		if err := json.Unmarshal(scanner.Bytes(), &line); err != nil {
			continue
		}
		if line.Type == "message_delta" || line.Type == "message_start" {
			if line.Usage.InputTokens > 0 || line.Usage.OutputTokens > 0 {
				inputTokens = line.Usage.InputTokens
				outputTokens = line.Usage.OutputTokens
			}
		}
	}
	return
}

// analyticsEvent is sent to the analytics sidecar's POST /capture endpoint.
type analyticsEvent struct {
	OrgID      string         `json:"org_id"`
	DistinctID string         `json:"distinct_id"`
	EventName  string         `json:"event_name"`
	Properties map[string]any `json:"properties"`
	Timestamp  time.Time      `json:"timestamp"`
}

type runner struct {
	mu      sync.Mutex
	running bool

	railsURL     string // e.g. http://rails:3000
	analyticsURL string // e.g. http://analytics:9100
	username     string
	password     string

	runsTotal       prometheus.Counter
	runsFailedTotal prometheus.Counter
	runDuration     prometheus.Histogram
	currentRuns     prometheus.Gauge
}

func newRunner(railsURL, analyticsURL, username, password string) *runner {
	return newRunnerWithRegistry(railsURL, analyticsURL, username, password, prometheus.DefaultRegisterer)
}

func newRunnerWithRegistry(railsURL, analyticsURL, username, password string, reg prometheus.Registerer) *runner {
	runsTotal := prometheus.NewCounter(prometheus.CounterOpts{
		Name: "runs_total",
		Help: "Total number of loop runs started.",
	})
	runsFailedTotal := prometheus.NewCounter(prometheus.CounterOpts{
		Name: "runs_failed_total",
		Help: "Total number of loop runs that exited non-zero.",
	})
	runDuration := prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "run_duration_seconds",
		Help:    "Duration of loop runs in seconds.",
		Buckets: prometheus.DefBuckets,
	})
	currentRuns := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "current_runs",
		Help: "Number of loop runs currently in progress.",
	})

	reg.MustRegister(runsTotal, runsFailedTotal, runDuration, currentRuns)

	return &runner{
		railsURL:        railsURL,
		analyticsURL:    analyticsURL,
		username:        username,
		password:        password,
		runsTotal:       runsTotal,
		runsFailedTotal: runsFailedTotal,
		runDuration:     runDuration,
		currentRuns:     currentRuns,
	}
}

func (r *runner) handleRun(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Basic Auth check.
	u, p, ok := req.BasicAuth()
	if !ok || u != r.username || p != r.password {
		w.Header().Set("WWW-Authenticate", `Basic realm="runner"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var body runRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if body.AgentRunID == "" {
		http.Error(w, "agent_run_id required", http.StatusUnprocessableEntity)
		return
	}

	script := body.Script
	if script == "" {
		script = "./loop.sh"
	}

	// Enforce one run at a time.
	r.mu.Lock()
	if r.running {
		r.mu.Unlock()
		http.Error(w, "run already in progress", http.StatusConflict)
		return
	}
	r.running = true
	r.mu.Unlock()

	w.WriteHeader(http.StatusAccepted)

	go func() {
		defer func() {
			r.mu.Lock()
			r.running = false
			r.mu.Unlock()
		}()

		r.runsTotal.Inc()
		r.currentRuns.Inc()
		start := time.Now()

		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Hour)
		defer cancel()

		cmd := exec.CommandContext(ctx, script)
		cmd.Env = append(os.Environ(), fmt.Sprintf("AGENT_RUN_ID=%s", body.AgentRunID))
		output, err := cmd.Output()

		elapsed := time.Since(start).Seconds()
		r.runDuration.Observe(elapsed)
		r.currentRuns.Dec()

		exitCode := 0
		if err != nil {
			exitCode = 1
			if exitErr, ok := err.(*exec.ExitError); ok {
				exitCode = exitErr.ExitCode()
			}
			r.runsFailedTotal.Inc()
			log.Printf("runner: run %s exited with error: %v", body.AgentRunID, err)
		} else {
			log.Printf("runner: run %s completed in %.1fs", body.AgentRunID, elapsed)
		}

		inputTokens, outputTokens := parseTokens(output)
		r.callComplete(body.AgentRunID, exitCode, inputTokens, outputTokens)
		r.sendAnalyticsEvent(body.AgentRunID, exitCode, inputTokens, outputTokens, elapsed)
	}()
}

func (r *runner) callComplete(agentRunID string, exitCode, inputTokens, outputTokens int) {
	payload := completePayload{
		ExitCode:     exitCode,
		InputTokens:  inputTokens,
		OutputTokens: outputTokens,
	}
	body, _ := json.Marshal(payload)

	url := fmt.Sprintf("%s/api/agent_runs/%s/complete", r.railsURL, agentRunID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		log.Printf("runner: failed to build complete request for %s: %v", agentRunID, err)
		return
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("runner: complete callback failed for %s: %v", agentRunID, err)
		return
	}
	defer resp.Body.Close()
	log.Printf("runner: complete callback for %s → %d", agentRunID, resp.StatusCode)
}

func (r *runner) sendAnalyticsEvent(agentRunID string, exitCode, inputTokens, outputTokens int, durationSecs float64) {
	if r.analyticsURL == "" {
		return
	}

	orgID := os.Getenv("DEFAULT_ORG_ID")
	if orgID == "" {
		orgID = "00000000-0000-0000-0000-000000000001"
	}

	evt := analyticsEvent{
		OrgID:      orgID,
		DistinctID: agentRunID,
		EventName:  "agent_run_completed",
		Timestamp:  time.Now().UTC(),
		Properties: map[string]any{
			"agent_run_id":  agentRunID,
			"exit_code":     exitCode,
			"input_tokens":  inputTokens,
			"output_tokens": outputTokens,
			"duration_secs": durationSecs,
		},
	}

	body, _ := json.Marshal(evt)
	url := fmt.Sprintf("%s/capture", r.analyticsURL)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		log.Printf("runner: failed to build analytics request for %s: %v", agentRunID, err)
		return
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("runner: analytics event failed for %s: %v", agentRunID, err)
		return
	}
	defer resp.Body.Close()
	log.Printf("runner: analytics event for %s → %d", agentRunID, resp.StatusCode)
}

func (r *runner) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func (r *runner) handleReady(w http.ResponseWriter, _ *http.Request) {
	r.mu.Lock()
	running := r.running
	r.mu.Unlock()
	if running {
		http.Error(w, "run in progress", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}

const testTimeout = 10 * time.Minute

func (r *runner) handleTest(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	u, p, ok := req.BasicAuth()
	if !ok || u != r.username || p != r.password {
		w.Header().Set("WWW-Authenticate", `Basic realm="runner"`)
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var body testRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil && err.Error() != "EOF" {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(req.Context(), testTimeout)
	defer cancel()

	args := []string{"compose", "-f", "infra/docker-compose.test.yml", "run", "--rm", "test"}
	if body.Spec != "" {
		args = append(args, "bundle", "exec", "rspec", body.Spec)
	}

	cmd := exec.CommandContext(ctx, "docker", args...)
	out, err := cmd.CombinedOutput()

	exitCode := 0
	if err != nil {
		exitCode = 1
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(testResponse{
		ExitCode: exitCode,
		Output:   string(out),
	})
}

func main() {
	railsURL := os.Getenv("RAILS_URL")
	if railsURL == "" {
		railsURL = "http://rails:3000"
	}
	analyticsURL := os.Getenv("ANALYTICS_URL")
	username := os.Getenv("RUNNER_USERNAME")
	if username == "" {
		username = "runner"
	}
	password := os.Getenv("RUNNER_PASSWORD")
	if password == "" {
		log.Fatal("runner: RUNNER_PASSWORD must be set")
	}

	r := newRunner(railsURL, analyticsURL, username, password)

	mux := http.NewServeMux()
	mux.HandleFunc("/run", r.handleRun)
	mux.HandleFunc("/test", r.handleTest)
	mux.HandleFunc("/healthz", r.handleHealthz)
	mux.HandleFunc("/ready", r.handleReady)
	mux.Handle("/metrics", promhttp.Handler())

	log.Printf("runner: listening on %s", port)
	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("runner: server error: %v", err)
	}
}
