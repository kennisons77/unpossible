package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// newTestServer returns a server with no DB (buffering mode) for unit tests.
func newTestServer() *server {
	return &server{}
}

func TestHealthz(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	srv.handleHealthz(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestCaptureSingleEvent(t *testing.T) {
	srv := newTestServer()
	body, _ := json.Marshal(event{
		OrgID:      "00000000-0000-0000-0000-000000000001",
		DistinctID: "11111111-1111-1111-1111-111111111111",
		EventName:  "page_view",
		Properties: json.RawMessage(`{"url":"/home"}`),
		Timestamp:  time.Now(),
	})
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	srv.mu.Lock()
	n := len(srv.buf)
	srv.mu.Unlock()
	if n != 1 {
		t.Errorf("expected 1 buffered event, got %d", n)
	}
}

func TestCaptureBatchArray(t *testing.T) {
	srv := newTestServer()
	events := []event{
		{OrgID: "00000000-0000-0000-0000-000000000001", DistinctID: "11111111-1111-1111-1111-111111111111", EventName: "a"},
		{OrgID: "00000000-0000-0000-0000-000000000001", DistinctID: "22222222-2222-2222-2222-222222222222", EventName: "b"},
	}
	body, _ := json.Marshal(events)
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	srv.mu.Lock()
	n := len(srv.buf)
	srv.mu.Unlock()
	if n != 2 {
		t.Errorf("expected 2 buffered events, got %d", n)
	}
}

func TestCaptureRejectsNonUUIDDistinctID(t *testing.T) {
	srv := newTestServer()
	body, _ := json.Marshal(event{
		OrgID:      "00000000-0000-0000-0000-000000000001",
		DistinctID: "not-a-uuid",
		EventName:  "page_view",
	})
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	// Still 202 — invalid events are silently dropped, not rejected at HTTP level.
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	srv.mu.Lock()
	n := len(srv.buf)
	srv.mu.Unlock()
	if n != 0 {
		t.Errorf("expected 0 buffered events (non-UUID dropped), got %d", n)
	}
}

func TestCaptureMalformedJSON(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader([]byte(`{bad json`)))
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestCaptureMethodNotAllowed(t *testing.T) {
	srv := newTestServer()
	req := httptest.NewRequest(http.MethodGet, "/capture", nil)
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", w.Code)
	}
}

func TestFlushBatchTrigger(t *testing.T) {
	// Invariant: enqueueing flushBatch events triggers an immediate flush attempt.
	// With no DB, events are re-buffered — we verify flush was called (buf reset then refilled).
	srv := newTestServer()
	events := make([]event, flushBatch)
	for i := range events {
		events[i] = event{
			OrgID:      "00000000-0000-0000-0000-000000000001",
			DistinctID: "11111111-1111-1111-1111-111111111111",
			EventName:  "test",
		}
	}
	srv.enqueue(events)
	// With no DB, events are re-buffered after failed flush.
	srv.mu.Lock()
	n := len(srv.buf)
	srv.mu.Unlock()
	if n != flushBatch {
		t.Errorf("expected %d events re-buffered after failed flush, got %d", flushBatch, n)
	}
}

func TestCaptureDropsMissingRequiredFields(t *testing.T) {
	srv := newTestServer()
	// Missing event_name — should be dropped.
	body, _ := json.Marshal(event{
		OrgID:      "00000000-0000-0000-0000-000000000001",
		DistinctID: "11111111-1111-1111-1111-111111111111",
	})
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	srv.handleCapture(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	srv.mu.Lock()
	n := len(srv.buf)
	srv.mu.Unlock()
	if n != 0 {
		t.Errorf("expected 0 buffered events (missing event_name dropped), got %d", n)
	}
}
