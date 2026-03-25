package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/unpossible/dashboard/metrics"
	"github.com/unpossible/dashboard/parser"
	"github.com/unpossible/dashboard/runner"
	"github.com/unpossible/dashboard/web"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)
	
	workspaceDir := os.Getenv("WORKSPACE_DIR")
	if workspaceDir == "" {
		workspaceDir = "/workspace"
	}
	
	loopScript := os.Getenv("LOOP_SCRIPT")
	if loopScript == "" {
		loopScript = workspaceDir + "/loop.sh"
	}
	
	runAuthUser := os.Getenv("RUN_AUTH_USER")
	runAuthPass := os.Getenv("RUN_AUTH_PASS")
	
	loopRunner := runner.New(loopScript)
	m := metrics.New()

	mux := http.NewServeMux()
	
	mux.Handle("/", http.FileServer(http.FS(web.FS)))
	
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ready"))
	})
	
	mux.HandleFunc("/api/plan", func(w http.ResponseWriter, r *http.Request) {
		planPath := workspaceDir + "/IMPLEMENTATION_PLAN.md"
		plan, err := parser.ParseImplementationPlan(planPath)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(plan)
	})
	
	mux.HandleFunc("/api/worklog", func(w http.ResponseWriter, r *http.Request) {
		worklogPath := workspaceDir + "/WORKLOG.md"
		worklog, err := parser.ParseWorklog(worklogPath)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(worklog)
	})
	
	mux.HandleFunc("/api/specs", func(w http.ResponseWriter, r *http.Request) {
		specsDir := workspaceDir + "/specs"
		list, err := parser.ListSpecs(specsDir)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(list)
	})
	
	mux.HandleFunc("/api/specs/", func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(r.URL.Path, "/api/specs/")
		if name == "" {
			http.Error(w, "spec name required", http.StatusBadRequest)
			return
		}
		
		specsDir := workspaceDir + "/specs"
		spec, err := parser.ReadSpec(specsDir, name)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(spec)
	})
	
	mux.HandleFunc("/run", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		
		user, pass, ok := r.BasicAuth()
		if !ok || user != runAuthUser || pass != runAuthPass {
			w.Header().Set("WWW-Authenticate", `Basic realm="dashboard"`)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		
		iterations := 0
		if iterStr := r.URL.Query().Get("iterations"); iterStr != "" {
			var err error
			iterations, err = strconv.Atoi(iterStr)
			if err != nil {
				http.Error(w, "invalid iterations parameter", http.StatusBadRequest)
				return
			}
		}
		
		go func() {
			m.IncRunsTotal()
			m.IncCurrentRuns()
			defer m.DecCurrentRuns()
			
			start := time.Now()
			ctx := context.Background()
			err := loopRunner.Run(ctx, iterations)
			duration := time.Since(start)
			
			m.RecordRunDuration(duration)
			
			if err != nil {
				m.IncRunsFailed()
				slog.Error("loop run failed", "error", err, "duration", duration.Seconds())
			} else {
				m.SetLastRunSuccess(time.Now())
				slog.Info("loop run completed", "duration", duration.Seconds())
			}
		}()
		
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]string{"status": "started"})
	})
	
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		w.Write([]byte(m.Export()))
	})
	
	addr := ":8080"
	slog.Info("starting server", "addr", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
