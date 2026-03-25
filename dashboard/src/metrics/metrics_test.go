package metrics

import (
	"strings"
	"testing"
	"time"
)

func TestMetricsIncRunsTotal(t *testing.T) {
	m := New()
	m.IncRunsTotal()
	m.IncRunsTotal()
	
	out := m.Export()
	if !strings.Contains(out, "runs_total 2") {
		t.Errorf("expected runs_total 2 in output, got: %s", out)
	}
}

func TestMetricsIncRunsFailed(t *testing.T) {
	m := New()
	m.IncRunsFailed()
	
	out := m.Export()
	if !strings.Contains(out, "runs_failed_total 1") {
		t.Errorf("expected runs_failed_total 1 in output, got: %s", out)
	}
}

func TestMetricsCurrentRuns(t *testing.T) {
	m := New()
	m.IncCurrentRuns()
	m.IncCurrentRuns()
	m.DecCurrentRuns()
	
	out := m.Export()
	if !strings.Contains(out, "current_runs 1") {
		t.Errorf("expected current_runs 1 in output, got: %s", out)
	}
}

func TestMetricsLastRunSuccess(t *testing.T) {
	m := New()
	ts := time.Date(2026, 3, 25, 12, 0, 0, 0, time.UTC)
	m.SetLastRunSuccess(ts)
	
	out := m.Export()
	if !strings.Contains(out, "last_run_success_timestamp") {
		t.Errorf("expected last_run_success_timestamp in output, got: %s", out)
	}
	if !strings.Contains(out, "177") {
		t.Errorf("expected timestamp starting with 177 (year 2026), got: %s", out)
	}
}

func TestMetricsRunDuration(t *testing.T) {
	m := New()
	m.RecordRunDuration(5 * time.Second)
	
	out := m.Export()
	if !strings.Contains(out, "run_duration_seconds 5.") {
		t.Errorf("expected run_duration_seconds 5.x in output, got: %s", out)
	}
}
