package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseImplementationPlan(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    []Task
	}{
		{
			name: "mixed done and pending tasks",
			content: `# Implementation Plan

- [x] First task done
- [ ] Second task pending
- [x] Third task done`,
			want: []Task{
				{Description: "First task done", Done: true},
				{Description: "Second task pending", Done: false},
				{Description: "Third task done", Done: true},
			},
		},
		{
			name:    "empty file",
			content: "",
			want:    []Task{},
		},
		{
			name: "no tasks",
			content: `# Implementation Plan

Some text without tasks.`,
			want: []Task{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			path := filepath.Join(tmpDir, "plan.md")
			
			if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
				t.Fatalf("writing test file: %v", err)
			}
			
			plan, err := ParseImplementationPlan(path)
			if err != nil {
				t.Fatalf("ParseImplementationPlan failed: %v", err)
			}
			
			if len(plan.Tasks) != len(tt.want) {
				t.Fatalf("got %d tasks, want %d", len(plan.Tasks), len(tt.want))
			}
			
			for i, task := range plan.Tasks {
				if task.Description != tt.want[i].Description {
					t.Errorf("task %d: got description %q, want %q", i, task.Description, tt.want[i].Description)
				}
				if task.Done != tt.want[i].Done {
					t.Errorf("task %d: got done=%v, want %v", i, task.Done, tt.want[i].Done)
				}
			}
		})
	}
}

func TestParseImplementationPlanFileNotFound(t *testing.T) {
	_, err := ParseImplementationPlan("/nonexistent/path")
	if err == nil {
		t.Fatal("expected error for nonexistent file, got nil")
	}
}
