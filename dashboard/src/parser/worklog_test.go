package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseWorklog(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    []WorklogEntry
	}{
		{
			name: "multiple entries",
			content: `# Worklog

## 2026-03-25T10:00:00Z — First entry

Some description here.
Multiple lines.

## 2026-03-25T11:00:00Z — Second entry

Another description.`,
			want: []WorklogEntry{
				{
					Timestamp:   "2026-03-25T10:00:00Z",
					Title:       "First entry",
					Description: "Some description here.\nMultiple lines.",
				},
				{
					Timestamp:   "2026-03-25T11:00:00Z",
					Title:       "Second entry",
					Description: "Another description.",
				},
			},
		},
		{
			name:    "empty file",
			content: "",
			want:    []WorklogEntry{},
		},
		{
			name: "no entries",
			content: `# Worklog

Some text without entries.`,
			want: []WorklogEntry{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			path := filepath.Join(tmpDir, "worklog.md")
			
			if err := os.WriteFile(path, []byte(tt.content), 0644); err != nil {
				t.Fatalf("writing test file: %v", err)
			}
			
			worklog, err := ParseWorklog(path)
			if err != nil {
				t.Fatalf("ParseWorklog failed: %v", err)
			}
			
			if len(worklog.Entries) != len(tt.want) {
				t.Fatalf("got %d entries, want %d", len(worklog.Entries), len(tt.want))
			}
			
			for i, entry := range worklog.Entries {
				if entry.Timestamp != tt.want[i].Timestamp {
					t.Errorf("entry %d: got timestamp %q, want %q", i, entry.Timestamp, tt.want[i].Timestamp)
				}
				if entry.Title != tt.want[i].Title {
					t.Errorf("entry %d: got title %q, want %q", i, entry.Title, tt.want[i].Title)
				}
				if entry.Description != tt.want[i].Description {
					t.Errorf("entry %d: got description %q, want %q", i, entry.Description, tt.want[i].Description)
				}
			}
		})
	}
}

func TestParseWorklogFileNotFound(t *testing.T) {
	_, err := ParseWorklog("/nonexistent/path")
	if err == nil {
		t.Fatal("expected error for nonexistent file, got nil")
	}
}
