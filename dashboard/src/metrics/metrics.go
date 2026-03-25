package metrics

import (
	"fmt"
	"sync"
	"time"
)

type Metrics struct {
	mu                    sync.RWMutex
	runsTotal             int64
	runsFailedTotal       int64
	currentRuns           int64
	lastRunSuccessTime    time.Time
	runDurations          []float64
}

func New() *Metrics {
	return &Metrics{}
}

func (m *Metrics) IncRunsTotal() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.runsTotal++
}

func (m *Metrics) IncRunsFailed() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.runsFailedTotal++
}

func (m *Metrics) IncCurrentRuns() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.currentRuns++
}

func (m *Metrics) DecCurrentRuns() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.currentRuns--
}

func (m *Metrics) RecordRunDuration(d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.runDurations = append(m.runDurations, d.Seconds())
}

func (m *Metrics) SetLastRunSuccess(t time.Time) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.lastRunSuccessTime = t
}

func (m *Metrics) Export() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	var out string
	out += fmt.Sprintf("# HELP runs_total Total number of loop runs\n")
	out += fmt.Sprintf("# TYPE runs_total counter\n")
	out += fmt.Sprintf("runs_total %d\n", m.runsTotal)
	
	out += fmt.Sprintf("# HELP runs_failed_total Total number of failed loop runs\n")
	out += fmt.Sprintf("# TYPE runs_failed_total counter\n")
	out += fmt.Sprintf("runs_failed_total %d\n", m.runsFailedTotal)
	
	out += fmt.Sprintf("# HELP current_runs Number of currently running loops\n")
	out += fmt.Sprintf("# TYPE current_runs gauge\n")
	out += fmt.Sprintf("current_runs %d\n", m.currentRuns)
	
	if !m.lastRunSuccessTime.IsZero() {
		out += fmt.Sprintf("# HELP last_run_success_timestamp Unix timestamp of last successful run\n")
		out += fmt.Sprintf("# TYPE last_run_success_timestamp gauge\n")
		out += fmt.Sprintf("last_run_success_timestamp %d\n", m.lastRunSuccessTime.Unix())
	}
	
	if len(m.runDurations) > 0 {
		out += fmt.Sprintf("# HELP run_duration_seconds Duration of loop runs in seconds\n")
		out += fmt.Sprintf("# TYPE run_duration_seconds histogram\n")
		for _, d := range m.runDurations {
			out += fmt.Sprintf("run_duration_seconds %f\n", d)
		}
	}
	
	return out
}
