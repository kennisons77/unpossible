// Analytics ingest sidecar — POST /capture (202 immediate), GET /healthz.
// In-memory queue flushed to Postgres every 5s or 100 events, whichever first.
// Non-UUID distinct_id rejected before enqueue. Properties PII-filtered before storage.
// Buffers in memory on Postgres unavailability — no events dropped on brief outage.
// Graceful shutdown: SIGTERM flushes remaining queue before exit.
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	_ "github.com/lib/pq"
)

const (
	port          = ":9100"
	flushInterval = 5 * time.Second
	flushBatch    = 100
	maxQueueSize  = 10_000
)

// uuidRE matches a canonical UUID (8-4-4-4-12 hex).
var uuidRE = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// piiPatterns are regex patterns that flag a property value as PII.
// Matched values are replaced with "[FILTERED]".
var piiPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}`), // email
}

// event mirrors the JSON body sent by callers (e.g. the runner sidecar).
type event struct {
	OrgID      string         `json:"org_id"`
	DistinctID string         `json:"distinct_id"`
	EventName  string         `json:"event_name"`
	Properties map[string]any `json:"properties"`
	Timestamp  time.Time      `json:"timestamp"`
}

// filterPII replaces property values that match PII patterns with "[FILTERED]".
// Only string values are scanned; non-string values are passed through.
func filterPII(props map[string]any) map[string]any {
	if props == nil {
		return props
	}
	out := make(map[string]any, len(props))
	for k, v := range props {
		s, ok := v.(string)
		if !ok {
			out[k] = v
			continue
		}
		filtered := false
		for _, re := range piiPatterns {
			if re.MatchString(s) {
				out[k] = "[FILTERED]"
				filtered = true
				break
			}
		}
		if !filtered {
			out[k] = v
		}
	}
	return out
}

type ingestor struct {
	db *sql.DB

	mu    sync.Mutex
	queue []event

	flush chan struct{} // signal flush goroutine to flush immediately
}

func newIngestor(db *sql.DB) *ingestor {
	return &ingestor{
		db:    db,
		queue: make([]event, 0, flushBatch),
		flush: make(chan struct{}, 1),
	}
}

// enqueue adds an event to the in-memory queue.
// Returns false if the queue is at capacity (event dropped, logged).
func (ing *ingestor) enqueue(e event) bool {
	ing.mu.Lock()
	defer ing.mu.Unlock()
	if len(ing.queue) >= maxQueueSize {
		log.Printf("analytics: queue full (%d), dropping event %s", maxQueueSize, e.EventName)
		return false
	}
	ing.queue = append(ing.queue, e)
	if len(ing.queue) >= flushBatch {
		// Non-blocking signal — flush goroutine may already be running.
		select {
		case ing.flush <- struct{}{}:
		default:
		}
	}
	return true
}

// drain removes and returns up to flushBatch events from the queue.
func (ing *ingestor) drain() []event {
	ing.mu.Lock()
	defer ing.mu.Unlock()
	if len(ing.queue) == 0 {
		return nil
	}
	n := len(ing.queue)
	if n > flushBatch {
		n = flushBatch
	}
	batch := make([]event, n)
	copy(batch, ing.queue[:n])
	ing.queue = ing.queue[n:]
	return batch
}

// flushAll drains and writes all queued events, looping until the queue is empty.
func (ing *ingestor) flushAll() {
	for {
		batch := ing.drain()
		if len(batch) == 0 {
			return
		}
		if err := ing.writeBatch(batch); err != nil {
			// Postgres unavailable — put events back at the front of the queue.
			log.Printf("analytics: flush failed (%v), re-queuing %d events", err, len(batch))
			ing.mu.Lock()
			ing.queue = append(batch, ing.queue...)
			ing.mu.Unlock()
			return
		}
	}
}

// writeBatch inserts a slice of events into analytics_events in a single transaction.
func (ing *ingestor) writeBatch(batch []event) error {
	if ing.db == nil {
		return fmt.Errorf("no database connection")
	}
	tx, err := ing.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck

	stmt, err := tx.Prepare(`
		INSERT INTO analytics_events (org_id, distinct_id, event_name, properties, timestamp, received_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	now := time.Now().UTC()
	for _, e := range batch {
		props, _ := json.Marshal(filterPII(e.Properties))
		ts := e.Timestamp
		if ts.IsZero() {
			ts = now
		}
		if _, err := stmt.Exec(e.OrgID, e.DistinctID, e.EventName, string(props), ts, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// runFlusher runs the periodic flush loop until ctx is cancelled.
func (ing *ingestor) runFlusher(ctx context.Context) {
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			ing.flushAll()
		case <-ing.flush:
			ing.flushAll()
		case <-ctx.Done():
			// Final flush on shutdown.
			ing.flushAll()
			return
		}
	}
}

func (ing *ingestor) handleCapture(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Detect single event vs batch array by first non-whitespace byte.
	// Read the body into a RawMessage so we can inspect and re-decode.
	var raw json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	var events []event
	if len(raw) > 0 && raw[0] == '[' {
		if err := json.Unmarshal(raw, &events); err != nil {
			http.Error(w, "invalid JSON in array", http.StatusBadRequest)
			return
		}
	} else if len(raw) > 0 && raw[0] == '{' {
		var e event
		if err := json.Unmarshal(raw, &e); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}
		events = append(events, e)
	} else {
		http.Error(w, "expected JSON object or array", http.StatusBadRequest)
		return
	}

	var rejected []string
	for _, e := range events {
		if !uuidRE.MatchString(strings.TrimSpace(e.DistinctID)) {
			rejected = append(rejected, e.DistinctID)
			continue
		}
		ing.enqueue(e)
	}

	if len(rejected) > 0 && len(rejected) == len(events) {
		// All events rejected.
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnprocessableEntity)
		json.NewEncoder(w).Encode(map[string]any{ //nolint:errcheck
			"error":    "distinct_id must be a UUID",
			"rejected": rejected,
		})
		return
	}

	w.WriteHeader(http.StatusAccepted)
}

func handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		host := os.Getenv("DB_HOST")
		if host == "" {
			host = "postgres"
		}
		user := os.Getenv("POSTGRES_USER")
		if user == "" {
			user = "unpossible"
		}
		pass := os.Getenv("POSTGRES_PASSWORD")
		if pass == "" {
			pass = "unpossible"
		}
		dbname := os.Getenv("POSTGRES_DB")
		if dbname == "" {
			dbname = "unpossible_development"
		}
		dsn = fmt.Sprintf("host=%s user=%s password=%s dbname=%s sslmode=disable", host, user, pass, dbname)
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		// Fail open — sidecar starts even if DB is unreachable at boot.
		log.Printf("analytics: failed to open DB connection: %v — buffering events", err)
		db = nil
	}
	if db != nil {
		defer db.Close()
	}

	ing := newIngestor(db)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go ing.runFlusher(ctx)

	mux := http.NewServeMux()
	mux.HandleFunc("/capture", ing.handleCapture)
	mux.HandleFunc("/healthz", handleHealthz)

	srv := &http.Server{
		Addr:    port,
		Handler: mux,
	}

	// Graceful shutdown on SIGTERM / SIGINT.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-sigCh
		log.Println("analytics: shutting down")
		cancel() // triggers final flush in runFlusher
		shutCtx, shutCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutCancel()
		srv.Shutdown(shutCtx) //nolint:errcheck
	}()

	log.Printf("analytics: listening on %s", port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("analytics: server error: %v", err)
	}
}
