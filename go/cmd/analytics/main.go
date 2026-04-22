// Analytics ingest sidecar — POST /capture, GET /healthz.
// Accepts single events or batch arrays, queues in memory, flushes to Postgres
// every 5 seconds or 100 events, whichever comes first.
// Internal network only — no auth required.
package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"regexp"
	"sync"
	"time"

	_ "github.com/lib/pq"
	"github.com/unpossible/unpossible/internal/pgclient"
	"github.com/unpossible/unpossible/internal/piifilter"
)

const (
	flushInterval     = 5 * time.Second
	flushBatch        = 100
	port              = ":9100"
	reconnectInterval = 5 * time.Second
)

var uuidRE = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// event mirrors the analytics_events table columns.
type event struct {
	OrgID      string          `json:"org_id"`
	DistinctID string          `json:"distinct_id"`
	EventName  string          `json:"event_name"`
	NodeID     string          `json:"node_id"`
	Properties json.RawMessage `json:"properties"`
	Timestamp  time.Time       `json:"timestamp"`
}

type server struct {
	dsn string
	db  *sql.DB
	mu  sync.Mutex
	buf []event
}

func (s *server) enqueue(events []event) {
	s.mu.Lock()
	s.buf = append(s.buf, events...)
	shouldFlush := len(s.buf) >= flushBatch
	s.mu.Unlock()
	if shouldFlush {
		s.flush()
	}
}

func (s *server) flush() {
	s.mu.Lock()
	if len(s.buf) == 0 {
		s.mu.Unlock()
		return
	}
	batch := s.buf
	s.buf = nil
	db := s.db
	s.mu.Unlock()

	if db == nil {
		// Postgres unavailable — put events back in buffer (fail open).
		s.mu.Lock()
		s.buf = append(batch, s.buf...)
		s.mu.Unlock()
		log.Printf("analytics: flush skipped — no db connection, buffering %d events", len(batch))
		s.tryReconnect()
		return
	}

	if err := s.insertBatch(db, batch); err != nil {
		s.mu.Lock()
		s.buf = append(batch, s.buf...)
		s.mu.Unlock()
		log.Printf("analytics: flush failed: %v — buffering %d events", err, len(batch))
		s.tryReconnect()
	} else {
		log.Printf("analytics: flushed %d events", len(batch))
	}
}

func (s *server) insertBatch(db *sql.DB, batch []event) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	stmt, err := tx.Prepare(`INSERT INTO analytics_events
		(org_id, distinct_id, event_name, node_id, properties, timestamp, received_at)
		VALUES ($1, $2, $3, NULLIF($4,''), $5, $6, NOW())`)
	if err != nil {
		tx.Rollback()
		return err
	}
	defer stmt.Close()

	for _, e := range batch {
		props := "{}"
		if len(e.Properties) > 0 {
			props = piifilter.Redact(string(e.Properties))
		}
		ts := e.Timestamp
		if ts.IsZero() {
			ts = time.Now().UTC()
		}
		if _, err := stmt.Exec(e.OrgID, e.DistinctID, e.EventName, e.NodeID, props, ts); err != nil {
			tx.Rollback()
			return err
		}
	}
	return tx.Commit()
}

// tryReconnect attempts to re-establish the DB connection in the background.
// No-op if already connected.
func (s *server) tryReconnect() {
	s.mu.Lock()
	alreadyConnected := s.db != nil
	s.mu.Unlock()
	if alreadyConnected {
		return
	}
	go func() {
		db, err := pgclient.Open(s.dsn)
		if err != nil {
			return
		}
		s.mu.Lock()
		s.db = db
		s.mu.Unlock()
		log.Printf("analytics: reconnected to postgres")
	}()
}

func (s *server) handleCapture(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var raw json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	// Accept single event or array.
	var events []event
	if len(raw) > 0 && raw[0] == '[' {
		if err := json.Unmarshal(raw, &events); err != nil {
			http.Error(w, "invalid event array", http.StatusBadRequest)
			return
		}
	} else {
		var e event
		if err := json.Unmarshal(raw, &e); err != nil {
			http.Error(w, "invalid event", http.StatusBadRequest)
			return
		}
		events = []event{e}
	}

	// Validate and filter events.
	valid := events[:0]
	for _, e := range events {
		if e.EventName == "" || e.OrgID == "" {
			continue // drop events missing required fields
		}
		if !uuidRE.MatchString(e.DistinctID) {
			log.Printf("analytics: rejected non-UUID distinct_id: %q", e.DistinctID)
			continue
		}
		valid = append(valid, e)
	}

	if len(valid) > 0 {
		s.enqueue(valid)
	}
	w.WriteHeader(http.StatusAccepted)
}

func (s *server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://unpossible:unpossible@localhost:5432/unpossible_development?sslmode=disable"
	}

	db, err := pgclient.Open(dsn)
	if err != nil {
		// Fail open — start without DB, buffer events until Postgres is available.
		log.Printf("analytics: postgres unavailable at startup: %v — buffering mode", err)
		db = nil
	}

	srv := &server{dsn: dsn, db: db}

	// Periodic flush goroutine.
	go func() {
		ticker := time.NewTicker(flushInterval)
		defer ticker.Stop()
		for range ticker.C {
			srv.flush()
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/capture", srv.handleCapture)
	mux.HandleFunc("/healthz", srv.handleHealthz)

	log.Printf("analytics: listening on %s", port)
	if err := http.ListenAndServe(port, mux); err != nil {
		log.Fatalf("analytics: server error: %v", err)
	}
}
