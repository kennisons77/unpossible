// Package pgclient provides a shared Postgres connection pool with retry logic.
// The lib/pq driver must be imported as a side-effect by the consuming binary.
package pgclient

import (
	"database/sql"
	"fmt"
	"time"
)

const (
	maxRetries    = 5
	retryInterval = 2 * time.Second
)

// Open opens a Postgres connection pool, retrying up to maxRetries times on
// transient connection errors. The caller is responsible for closing the pool.
func Open(dsn string) (*sql.DB, error) {
	var db *sql.DB
	var err error
	for i := range maxRetries {
		db, err = sql.Open("postgres", dsn)
		if err != nil {
			return nil, fmt.Errorf("pgclient: open: %w", err)
		}
		if pingErr := db.Ping(); pingErr == nil {
			return db, nil
		}
		db.Close()
		if i < maxRetries-1 {
			time.Sleep(retryInterval)
		}
	}
	return nil, fmt.Errorf("pgclient: could not connect after %d attempts: %w", maxRetries, err)
}
