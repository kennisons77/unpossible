package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// --- filterPII ---

func TestFilterPIIRedactsEmail(t *testing.T) {
	// Invariant: email addresses in property values are replaced with [FILTERED].
	props := map[string]any{"user": "alice@example.com", "count": 3}
	out := filterPII(props)
	if out["user"] != "[FILTERED]" {
		t.Errorf("expected [FILTERED], got %v", out["user"])
	}
	if out["count"] != 3 {
		t.Errorf("expected count 3 unchanged, got %v", out["count"])
	}
}

func TestFilterPIIPassesSafeValues(t *testing.T) {
	props := map[string]any{"event": "click", "duration": 1.5}
	out := filterPII(props)
	if out["event"] != "click" {
		t.Errorf("expected click, got %v", out["event"])
	}
}

func TestFilterPIINilProps(t *testing.T) {
	if filterPII(nil) != nil {
		t.Error("expected nil for nil input")
	}
}

// --- UUID validation ---

func TestUUIDREAcceptsValidUUID(t *testing.T) {
	valid := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	if !uuidRE.MatchString(valid) {
		t.Errorf("expected %s to match UUID pattern", valid)
	}
}

func TestUUIDRERejectsEmail(t *testing.T) {
	if uuidRE.MatchString("user@example.com") {
		t.Error("expected email to fail UUID pattern")
	}
}

func TestUUIDRERejectsPlainString(t *testing.T) {
	if uuidRE.MatchString("not-a-uuid") {
		t.Error("expected plain string to fail UUID pattern")
	}
}

// --- ingestor queue ---

func TestEnqueueAndDrain(t *testing.T) {
	ing := newIngestor(nil)
	e := event{OrgID: "org1", DistinctID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", EventName: "test"}
	ing.enqueue(e)
	batch := ing.drain()
	if len(batch) != 1 {
		t.Fatalf("expected 1 event, got %d", len(batch))
	}
	if batch[0].EventName != "test" {
		t.Errorf("expected event_name test, got %s", batch[0].EventName)
	}
}

func TestDrainEmptyQueue(t *testing.T) {
	ing := newIngestor(nil)
	if batch := ing.drain(); batch != nil {
		t.Errorf("expected nil for empty queue, got %v", batch)
	}
}

func TestEnqueueDropsAtCapacity(t *testing.T) {
	// Invariant: queue capped at maxQueueSize — overflow events are dropped, not OOM.
	ing := newIngestor(nil)
	ing.mu.Lock()
	for i := 0; i < maxQueueSize; i++ {
		ing.queue = append(ing.queue, event{EventName: "fill"})
	}
	ing.mu.Unlock()
	ok := ing.enqueue(event{EventName: "overflow"})
	if ok {
		t.Error("expected enqueue to return false when queue is full")
	}
	ing.mu.Lock()
	n := len(ing.queue)
	ing.mu.Unlock()
	if n != maxQueueSize {
		t.Errorf("expected queue size %d, got %d", maxQueueSize, n)
	}
}

func TestEnqueueSignalsFlushAtBatchSize(t *testing.T) {
	// Invariant: reaching flushBatch events sends a signal on the flush channel.
	ing := newIngestor(nil)
	ing.mu.Lock()
	for i := 0; i < flushBatch-1; i++ {
		ing.queue = append(ing.queue, event{EventName: "fill"})
	}
	ing.mu.Unlock()
	ing.enqueue(event{EventName: "trigger"})
	select {
	case <-ing.flush:
		// expected
	case <-time.After(100 * time.Millisecond):
		t.Error("expected flush signal after reaching batch size")
	}
}

// --- HTTP handlers ---

func TestHealthz(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	w := httptest.NewRecorder()
	handleHealthz(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestCaptureRejectsNonPost(t *testing.T) {
	ing := newIngestor(nil)
	req := httptest.NewRequest(http.MethodGet, "/capture", nil)
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("expected 405, got %d", w.Code)
	}
}

func TestCaptureRejectsNonUUIDDistinctID(t *testing.T) {
	// Invariant: non-UUID distinct_id rejected with 422 before storage.
	ing := newIngestor(nil)
	body, _ := json.Marshal(event{
		OrgID:      "org1",
		DistinctID: "not-a-uuid",
		EventName:  "test",
	})
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	if w.Code != http.StatusUnprocessableEntity {
		t.Errorf("expected 422 for non-UUID distinct_id, got %d", w.Code)
	}
	if len(ing.queue) != 0 {
		t.Error("expected no events enqueued after rejection")
	}
}

func TestCaptureAcceptsSingleEvent(t *testing.T) {
	// Invariant: POST /capture returns 202 immediately for valid single event.
	ing := newIngestor(nil)
	body, _ := json.Marshal(event{
		OrgID:      "org1",
		DistinctID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		EventName:  "page_view",
	})
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	if len(ing.queue) != 1 {
		t.Errorf("expected 1 event queued, got %d", len(ing.queue))
	}
}

func TestCaptureAcceptsBatchArray(t *testing.T) {
	// Invariant: POST /capture accepts a JSON array of events.
	ing := newIngestor(nil)
	events := []event{
		{OrgID: "org1", DistinctID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", EventName: "e1"},
		{OrgID: "org1", DistinctID: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff", EventName: "e2"},
	}
	body, _ := json.Marshal(events)
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202, got %d", w.Code)
	}
	if len(ing.queue) != 2 {
		t.Errorf("expected 2 events queued, got %d", len(ing.queue))
	}
}

func TestCaptureBatchPartialReject(t *testing.T) {
	// Invariant: valid events in a batch are enqueued even if some are rejected.
	ing := newIngestor(nil)
	events := []event{
		{OrgID: "org1", DistinctID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", EventName: "valid"},
		{OrgID: "org1", DistinctID: "not-a-uuid", EventName: "invalid"},
	}
	body, _ := json.Marshal(events)
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader(body))
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	// Partial success — 202 because at least one event was accepted.
	if w.Code != http.StatusAccepted {
		t.Errorf("expected 202 for partial batch, got %d", w.Code)
	}
	if len(ing.queue) != 1 {
		t.Errorf("expected 1 valid event queued, got %d", len(ing.queue))
	}
}

func TestCaptureRejectsInvalidJSON(t *testing.T) {
	ing := newIngestor(nil)
	req := httptest.NewRequest(http.MethodPost, "/capture", bytes.NewReader([]byte("{bad")))
	w := httptest.NewRecorder()
	ing.handleCapture(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for invalid JSON, got %d", w.Code)
	}
}

func TestFlushAllNoOpOnEmptyQueue(t *testing.T) {
	// Should not panic or error when queue is empty.
	ing := newIngestor(nil)
	ing.flushAll() // no panic
}

func TestFlushAllRequeuesOnDBError(t *testing.T) {
	// Invariant: events are re-queued when Postgres is unavailable.
	ing := newIngestor(nil) // nil db → writeBatch returns error
	ing.enqueue(event{OrgID: "org1", DistinctID: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", EventName: "test"})
	ing.flushAll()
	// Event should be back in the queue.
	if len(ing.queue) != 1 {
		t.Errorf("expected event re-queued after DB error, got %d events", len(ing.queue))
	}
}
