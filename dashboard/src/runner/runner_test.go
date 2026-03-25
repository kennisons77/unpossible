package runner

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestRunnerIsRunning(t *testing.T) {
	r := New("/bin/true")
	
	if r.IsRunning() {
		t.Error("expected not running initially")
	}
}

func TestRunnerConcurrency(t *testing.T) {
	tmpDir := t.TempDir()
	script := filepath.Join(tmpDir, "test.sh")
	
	if err := os.WriteFile(script, []byte("#!/bin/sh\nsleep 0.1"), 0755); err != nil {
		t.Fatalf("writing test script: %v", err)
	}
	
	r := New(script)
	
	ctx := context.Background()
	go r.Run(ctx, 0)
	
	time.Sleep(10 * time.Millisecond)
	
	err := r.Run(ctx, 0)
	if err == nil {
		t.Fatal("expected error when running concurrently, got nil")
	}
}

func TestRunnerSuccess(t *testing.T) {
	tmpDir := t.TempDir()
	script := filepath.Join(tmpDir, "test.sh")
	
	if err := os.WriteFile(script, []byte("#!/bin/sh\nexit 0"), 0755); err != nil {
		t.Fatalf("writing test script: %v", err)
	}
	
	r := New(script)
	ctx := context.Background()
	
	if err := r.Run(ctx, 0); err != nil {
		t.Errorf("Run failed: %v", err)
	}
}

func TestRunnerFailure(t *testing.T) {
	tmpDir := t.TempDir()
	script := filepath.Join(tmpDir, "test.sh")
	
	if err := os.WriteFile(script, []byte("#!/bin/sh\nexit 1"), 0755); err != nil {
		t.Fatalf("writing test script: %v", err)
	}
	
	r := New(script)
	ctx := context.Background()
	
	err := r.Run(ctx, 0)
	if err == nil {
		t.Fatal("expected error for failing script, got nil")
	}
}
