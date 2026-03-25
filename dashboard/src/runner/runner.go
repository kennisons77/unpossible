package runner

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"time"
)

type Runner struct {
	loopScript string
	mu         sync.Mutex
	running    bool
}

func New(loopScript string) *Runner {
	return &Runner{loopScript: loopScript}
}

func (r *Runner) IsRunning() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.running
}

func (r *Runner) Run(ctx context.Context, iterations int) error {
	r.mu.Lock()
	if r.running {
		r.mu.Unlock()
		return fmt.Errorf("loop already running")
	}
	r.running = true
	r.mu.Unlock()
	
	defer func() {
		r.mu.Lock()
		r.running = false
		r.mu.Unlock()
	}()
	
	args := []string{r.loopScript}
	if iterations > 0 {
		args = append(args, fmt.Sprintf("%d", iterations))
	}
	
	cmd := exec.CommandContext(ctx, "/bin/sh", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("running loop: %w (output: %s)", err, output)
	}
	
	return nil
}

type Status struct {
	Running   bool      `json:"running"`
	LastRun   time.Time `json:"last_run,omitempty"`
	LastError string    `json:"last_error,omitempty"`
}

func (r *Runner) Status() Status {
	r.mu.Lock()
	defer r.mu.Unlock()
	return Status{Running: r.running}
}
