package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/unpossible/dashboard/parser"
)

func main() {
	workspaceDir := os.Getenv("WORKSPACE_DIR")
	if workspaceDir == "" {
		workspaceDir = "/workspace"
	}

	mux := http.NewServeMux()
	
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
	
	addr := ":8080"
	log.Printf("starting server on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
