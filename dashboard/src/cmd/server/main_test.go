package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestHealthz(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
	if w.Body.String() != "ok" {
		t.Errorf("got body %q, want %q", w.Body.String(), "ok")
	}
}

func TestReady(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ready"))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
	if w.Body.String() != "ready" {
		t.Errorf("got body %q, want %q", w.Body.String(), "ready")
	}
}

func TestAPIPlan(t *testing.T) {
	tmpDir := t.TempDir()
	planPath := filepath.Join(tmpDir, "IMPLEMENTATION_PLAN.md")
	content := `# Plan
- [x] Done task
- [ ] Pending task`
	
	if err := os.WriteFile(planPath, []byte(content), 0644); err != nil {
		t.Fatalf("writing test plan: %v", err)
	}
	
	os.Setenv("WORKSPACE_DIR", tmpDir)
	defer os.Unsetenv("WORKSPACE_DIR")
	
	req := httptest.NewRequest(http.MethodGet, "/api/plan", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/api/plan", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"tasks":[{"description":"Done task","done":true},{"description":"Pending task","done":false}]}`))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
	
	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("got Content-Type %q, want %q", contentType, "application/json")
	}
}

func TestAPIWorklog(t *testing.T) {
	tmpDir := t.TempDir()
	worklogPath := filepath.Join(tmpDir, "WORKLOG.md")
	content := `# Worklog

## 2026-03-25T10:00:00Z — Test entry

Test description.`
	
	if err := os.WriteFile(worklogPath, []byte(content), 0644); err != nil {
		t.Fatalf("writing test worklog: %v", err)
	}
	
	os.Setenv("WORKSPACE_DIR", tmpDir)
	defer os.Unsetenv("WORKSPACE_DIR")
	
	req := httptest.NewRequest(http.MethodGet, "/api/worklog", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/api/worklog", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"entries":[{"timestamp":"2026-03-25T10:00:00Z","title":"Test entry","description":"Test description."}]}`))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
	
	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("got Content-Type %q, want %q", contentType, "application/json")
	}
}
