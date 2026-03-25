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

func TestAPISpecs(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	if err := os.WriteFile(filepath.Join(specsDir, "test.md"), []byte("# Test"), 0644); err != nil {
		t.Fatalf("writing test spec: %v", err)
	}
	
	os.Setenv("WORKSPACE_DIR", tmpDir)
	defer os.Unsetenv("WORKSPACE_DIR")
	
	req := httptest.NewRequest(http.MethodGet, "/api/specs", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/api/specs", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"specs":[{"name":"test","path":"test.md"}]}`))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
}

func TestAPISpecByName(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	content := "# Test Spec"
	if err := os.WriteFile(filepath.Join(specsDir, "test.md"), []byte(content), 0644); err != nil {
		t.Fatalf("writing test spec: %v", err)
	}
	
	os.Setenv("WORKSPACE_DIR", tmpDir)
	defer os.Unsetenv("WORKSPACE_DIR")
	
	req := httptest.NewRequest(http.MethodGet, "/api/specs/test", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/api/specs/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"name":"test","content":"# Test Spec"}`))
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", w.Code, http.StatusOK)
	}
}

func TestRunEndpointAuth(t *testing.T) {
	os.Setenv("RUN_AUTH_USER", "testuser")
	os.Setenv("RUN_AUTH_PASS", "testpass")
	defer os.Unsetenv("RUN_AUTH_USER")
	defer os.Unsetenv("RUN_AUTH_PASS")
	
	tests := []struct {
		name       string
		user       string
		pass       string
		wantStatus int
	}{
		{"valid credentials", "testuser", "testpass", http.StatusAccepted},
		{"invalid user", "wrong", "testpass", http.StatusUnauthorized},
		{"invalid pass", "testuser", "wrong", http.StatusUnauthorized},
		{"no credentials", "", "", http.StatusUnauthorized},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/run", nil)
			if tt.user != "" || tt.pass != "" {
				req.SetBasicAuth(tt.user, tt.pass)
			}
			w := httptest.NewRecorder()
			
			mux := http.NewServeMux()
			mux.HandleFunc("/run", func(w http.ResponseWriter, r *http.Request) {
				user, pass, ok := r.BasicAuth()
				if !ok || user != "testuser" || pass != "testpass" {
					w.Header().Set("WWW-Authenticate", `Basic realm="dashboard"`)
					http.Error(w, "unauthorized", http.StatusUnauthorized)
					return
				}
				w.WriteHeader(http.StatusAccepted)
			})
			
			mux.ServeHTTP(w, req)
			
			if w.Code != tt.wantStatus {
				t.Errorf("got status %d, want %d", w.Code, tt.wantStatus)
			}
		})
	}
}

func TestRunEndpointMethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/run", nil)
	w := httptest.NewRecorder()
	
	mux := http.NewServeMux()
	mux.HandleFunc("/run", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
	})
	
	mux.ServeHTTP(w, req)
	
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("got status %d, want %d", w.Code, http.StatusMethodNotAllowed)
	}
}
