package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestListSpecs(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	files := map[string]string{
		"prd.md":     "# PRD",
		"plan.md":    "# Plan",
		"readme.txt": "not a markdown file",
	}
	
	for name, content := range files {
		path := filepath.Join(specsDir, name)
		if err := os.WriteFile(path, []byte(content), 0644); err != nil {
			t.Fatalf("writing %s: %v", name, err)
		}
	}
	
	list, err := ListSpecs(specsDir)
	if err != nil {
		t.Fatalf("ListSpecs failed: %v", err)
	}
	
	if len(list.Specs) != 2 {
		t.Fatalf("got %d specs, want 2", len(list.Specs))
	}
	
	names := make(map[string]bool)
	for _, spec := range list.Specs {
		names[spec.Name] = true
	}
	
	if !names["prd"] || !names["plan"] {
		t.Errorf("expected prd and plan, got %v", names)
	}
}

func TestReadSpec(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	content := "# Test Spec\n\nContent here."
	path := filepath.Join(specsDir, "test.md")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("writing test spec: %v", err)
	}
	
	spec, err := ReadSpec(specsDir, "test")
	if err != nil {
		t.Fatalf("ReadSpec failed: %v", err)
	}
	
	if spec.Name != "test" {
		t.Errorf("got name %q, want %q", spec.Name, "test")
	}
	if spec.Content != content {
		t.Errorf("got content %q, want %q", spec.Content, content)
	}
}

func TestReadSpecPathTraversal(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	_, err := ReadSpec(specsDir, "../etc/passwd")
	if err == nil {
		t.Fatal("expected error for path traversal, got nil")
	}
}

func TestReadSpecNotFound(t *testing.T) {
	tmpDir := t.TempDir()
	specsDir := filepath.Join(tmpDir, "specs")
	
	if err := os.MkdirAll(specsDir, 0755); err != nil {
		t.Fatalf("creating specs dir: %v", err)
	}
	
	_, err := ReadSpec(specsDir, "nonexistent")
	if err == nil {
		t.Fatal("expected error for nonexistent spec, got nil")
	}
}
