package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
)

// newTestRunner returns a runner with a fresh Prometheus registry to avoid duplicate registration panics.
func newTestRunner(railsURL string) *runner {
	return newRunnerWithRegistry(railsURL, "testuser", "testpass", prometheus.NewRegistry())
}

func TestHealthz(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	r.handleHealthz(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestReadyWhenIdle(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()
	r.handleReady(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200 when idle, got %d", w.Code)
	}
}

func TestReadyWhenRunning(t *testing.T) {
	r := newTestRunner("http://localhost")
	r.mu.Lock()
	r.running = true
	r.mu.Unlock()

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()
	r.handleReady(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected 503 when running, got %d", w.Code)
	}
}

func TestRunRequiresBasicAuth(t *testing.T) {
	r := newTestRunner("http://localhost")
	body, _ := json.Marshal(runRequest{AgentRunID: "abc-123"})
	req := httptest.NewRequest(http.MethodPost, "/run", bytes.NewReader(body))
	w := httptest.NewRecorder()
	r.handleRun(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 without auth, got %d", w.Code)
	}
}

func TestRunRejectsWrongCredentials(t *testing.T) {
	r := newTestRunner("http://localhost")
	body, _ := json.Marshal(runRequest{AgentRunID: "abc-123"})
	req := httptest.NewRequest(http.MethodPost, "/run", bytes.NewReader(body))
	req.SetBasicAuth("testuser", "wrongpass")
	w := httptest.NewRecorder()
	r.handleRun(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 with wrong password, got %d", w.Code)
	}
}

func TestRunRejectsMissingAgentRunID(t *testing.T) {
	r := newTestRunner("http://localhost")
	body, _ := json.Marshal(runRequest{})
	req := httptest.NewRequest(http.MethodPost, "/run", bytes.NewReader(body))
	req.SetBasicAuth("testuser", "testpass")
	w := httptest.NewRecorder()
	r.handleRun(w, req)
	if w.Code != http.StatusUnprocessableEntity {
		t.Errorf("expected 422 without agent_run_id, got %d", w.Code)
	}
}

func TestRunConflictWhenAlreadyRunning(t *testing.T) {
	// Invariant: concurrent POST /run returns 409 — only one run at a time.
	r := newTestRunner("http://localhost")
	r.mu.Lock()
	r.running = true
	r.mu.Unlock()

	body, _ := json.Marshal(runRequest{AgentRunID: "abc-123"})
	req := httptest.NewRequest(http.MethodPost, "/run", bytes.NewReader(body))
	req.SetBasicAuth("testuser", "testpass")
	w := httptest.NewRecorder()
	r.handleRun(w, req)
	if w.Code != http.StatusConflict {
		t.Errorf("expected 409 when already running, got %d", w.Code)
	}
}

func TestRunCallsCompleteCallback(t *testing.T) {
	// Invariant: after loop exits, runner POSTs to Rails complete endpoint.
	var received completePayload
	var callCount int

	mockRails := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		callCount++
		json.NewDecoder(req.Body).Decode(&received)
		w.WriteHeader(http.StatusOK)
	}))
	defer mockRails.Close()

	r := newTestRunner(mockRails.URL)
	// Directly call callComplete to test the callback without executing a real script.
	r.callComplete("run-999", 0, 42, 100)

	if callCount != 1 {
		t.Errorf("expected 1 callback, got %d", callCount)
	}
	if received.ExitCode != 0 {
		t.Errorf("expected exit_code 0, got %d", received.ExitCode)
	}
	if received.InputTokens != 42 {
		t.Errorf("expected input_tokens 42, got %d", received.InputTokens)
	}
	if received.OutputTokens != 100 {
		t.Errorf("expected output_tokens 100, got %d", received.OutputTokens)
	}
}

func TestParseTokensFromStreamJSON(t *testing.T) {
	// Invariant: token counts are extracted from Claude stream-json stdout.
	output := []byte(`{"type":"message_start","usage":{"input_tokens":150,"output_tokens":0}}
{"type":"content_block_start"}
{"type":"message_delta","usage":{"input_tokens":150,"output_tokens":320}}
`)
	in, out := parseTokens(output)
	if in != 150 {
		t.Errorf("expected input_tokens 150, got %d", in)
	}
	if out != 320 {
		t.Errorf("expected output_tokens 320, got %d", out)
	}
}

func TestParseTokensNoUsage(t *testing.T) {
	// Non-stream-json output returns zeros without error.
	output := []byte("some plain text output\nno json here\n")
	in, out := parseTokens(output)
	if in != 0 || out != 0 {
		t.Errorf("expected 0,0 for non-JSON output, got %d,%d", in, out)
	}
}

func TestRunMethodNotAllowed(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodGet, "/run", nil)
	w := httptest.NewRecorder()
	r.handleRun(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", w.Code)
	}
}

func TestTestRequiresBasicAuth(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodPost, "/test", nil)
	w := httptest.NewRecorder()
	r.handleTest(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 without auth, got %d", w.Code)
	}
}

func TestTestRejectsWrongCredentials(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodPost, "/test", nil)
	req.SetBasicAuth("testuser", "wrongpass")
	w := httptest.NewRecorder()
	r.handleTest(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 with wrong password, got %d", w.Code)
	}
}

func TestTestMethodNotAllowed(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	w := httptest.NewRecorder()
	r.handleTest(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", w.Code)
	}
}

func TestTestRejectsInvalidJSON(t *testing.T) {
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodPost, "/test", bytes.NewReader([]byte("{bad")))
	req.SetBasicAuth("testuser", "testpass")
	w := httptest.NewRecorder()
	r.handleTest(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for invalid JSON, got %d", w.Code)
	}
}

func TestTestAcceptsEmptyBody(t *testing.T) {
	// Empty body is valid — runs full test suite.
	// This will fail because docker isn't available in test, but it should
	// return a JSON response with a non-zero exit code, not an HTTP error.
	r := newTestRunner("http://localhost")
	req := httptest.NewRequest(http.MethodPost, "/test", bytes.NewReader([]byte("{}")))
	req.SetBasicAuth("testuser", "testpass")
	w := httptest.NewRecorder()
	r.handleTest(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200 (with non-zero exit_code), got %d", w.Code)
	}
	var resp testResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	// docker compose won't be available in test env, so exit code should be non-zero
	if resp.ExitCode == 0 {
		t.Log("docker compose succeeded unexpectedly — test env has Docker available")
	}
}
