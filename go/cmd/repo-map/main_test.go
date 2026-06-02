package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---- Helpers ----

func writeFile(t *testing.T, dir, rel, content string) {
	t.Helper()
	path := filepath.Join(dir, rel)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

// ---- Ruby extraction ----

func TestParseRuby_ClassAndMethods(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "app/models/user.rb", `
module Auth
  class User < ApplicationRecord
    include Concerns::Auditable

    def self.find_by_token(token)
      where(token: token).first
    end

    def full_name
      "#{first_name} #{last_name}"
    end

    private

    def secret_method
    end
  end
end
`)
	rel := "app/models/user.rb"
	content := parseRuby(filepath.Join(dir, rel), rel)

	if !strings.Contains(content, "Auth::User < ApplicationRecord") {
		t.Errorf("expected class with parent, got:\n%s", content)
	}
	if !strings.Contains(content, ".find_by_token") {
		t.Errorf("expected class method, got:\n%s", content)
	}
	if !strings.Contains(content, "#full_name") {
		t.Errorf("expected instance method, got:\n%s", content)
	}
	if strings.Contains(content, "#secret_method") {
		t.Errorf("private method should be excluded, got:\n%s", content)
	}
	if !strings.Contains(content, "include Concerns::Auditable") {
		t.Errorf("expected concern inclusion, got:\n%s", content)
	}
}

func TestParseRuby_ModuleOnly(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "app/lib/helper.rb", `
module MyHelper
  def format_date(date)
    date.strftime("%Y-%m-%d")
  end
end
`)
	rel := "app/lib/helper.rb"
	content := parseRuby(filepath.Join(dir, rel), rel)

	if !strings.Contains(content, "MyHelper") {
		t.Errorf("expected module name, got:\n%s", content)
	}
	if !strings.Contains(content, "#format_date") {
		t.Errorf("expected method, got:\n%s", content)
	}
}

func TestParseRuby_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "app/empty.rb", "# just a comment\n")
	content := parseRuby(filepath.Join(dir, "app/empty.rb"), "app/empty.rb")
	if content != "" {
		t.Errorf("expected empty output for file with no classes, got: %s", content)
	}
}

// ---- Go extraction ----

func TestParseGo_ExportedSymbols(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "cmd/runner/main.go", `package main

import "fmt"

type Server struct {
	port int
}

func NewServer(port int) *Server {
	return &Server{port: port}
}

func (s *Server) Start() error {
	fmt.Println("starting")
	return nil
}

func unexported() {}
`)
	rel := "cmd/runner/main.go"
	content := parseGo(filepath.Join(dir, rel), rel)

	if !strings.Contains(content, "package main") {
		t.Errorf("expected package declaration, got:\n%s", content)
	}
	if !strings.Contains(content, "type Server") {
		t.Errorf("expected exported type, got:\n%s", content)
	}
	if !strings.Contains(content, "func NewServer") {
		t.Errorf("expected exported function, got:\n%s", content)
	}
	if !strings.Contains(content, "func (Server) Start") {
		t.Errorf("expected exported method, got:\n%s", content)
	}
	if strings.Contains(content, "unexported") {
		t.Errorf("unexported function should be excluded, got:\n%s", content)
	}
}

func TestParseGo_NoExportedSymbols(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "cmd/runner/internal.go", `package main

func helper() string { return "" }
`)
	content := parseGo(filepath.Join(dir, "cmd/runner/internal.go"), "cmd/runner/internal.go")
	if content != "" {
		t.Errorf("expected empty output for file with no exported symbols, got: %s", content)
	}
}

// ---- Markdown extraction ----

func TestParseMarkdown_HeadingsAndDescription(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "specifications/system/agents/concept.md", `---
name: agents
kind: concept
description: Agent run lifecycle and storage
---

# Agent Runner

## What It Does

Some content here.

## Acceptance Criteria

More content.

### Sub-heading (should be excluded)
`)
	rel := "specifications/system/agents/concept.md"
	content := parseMarkdown(filepath.Join(dir, rel), rel)

	if !strings.Contains(content, "Agent run lifecycle and storage") {
		t.Errorf("expected description, got:\n%s", content)
	}
	if !strings.Contains(content, "# Agent Runner") {
		t.Errorf("expected H1, got:\n%s", content)
	}
	if !strings.Contains(content, "## What It Does") {
		t.Errorf("expected H2, got:\n%s", content)
	}
	if strings.Contains(content, "### Sub-heading") {
		t.Errorf("H3 should be excluded, got:\n%s", content)
	}
}

func TestParseMarkdown_NoFrontmatter(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "specifications/README.md", `# Overview

## Section One
`)
	rel := "specifications/README.md"
	content := parseMarkdown(filepath.Join(dir, rel), rel)

	if !strings.Contains(content, "# Overview") {
		t.Errorf("expected H1, got:\n%s", content)
	}
}

// ---- Test file exclusion ----

func TestIsTestFile(t *testing.T) {
	cases := []struct {
		path     string
		excluded bool
	}{
		{"web/spec/models/user_spec.rb", true},
		{"go/cmd/runner/main_test.go", true},
		{"web/app/models/user.rb", false},
		{"go/cmd/runner/main.go", false},
		{"specifications/system/concept.md", false},
	}
	for _, c := range cases {
		got := isTestFile(c.path)
		if got != c.excluded {
			t.Errorf("isTestFile(%q) = %v, want %v", c.path, got, c.excluded)
		}
	}
}

// ---- Token budget ----

func TestApproxTokens(t *testing.T) {
	// 4 chars = 1 token
	if approxTokens("abcd") != 1 {
		t.Errorf("expected 1 token for 4 chars")
	}
	if approxTokens("abcde") != 2 {
		t.Errorf("expected 2 tokens for 5 chars")
	}
	if approxTokens("") != 0 {
		t.Errorf("expected 0 tokens for empty string")
	}
}

// ---- Render with budget ----

func TestRender_RespectsTokenBudget(t *testing.T) {
	// Create entries that exceed a tiny budget
	entries := []*fileEntry{
		{path: "a.rb", content: strings.Repeat("x", 400), recency: 0},
		{path: "b.rb", content: strings.Repeat("y", 400), recency: 1},
	}
	// Budget of 10 tokens = 40 chars — should truncate
	output := render(entries, 10)
	if approxTokens(output) > 15 { // allow small overage from header
		t.Errorf("output exceeds budget: %d tokens", approxTokens(output))
	}
}

func TestRender_DeterministicOutput(t *testing.T) {
	entries := []*fileEntry{
		{path: "a.rb", content: "## a.rb\n\nClassA\n\n", recency: 0},
		{path: "b.rb", content: "## b.rb\n\nClassB\n\n", recency: 1},
	}
	out1 := render(entries, 1024)
	out2 := render(entries, 1024)
	if out1 != out2 {
		t.Errorf("render is not deterministic")
	}
}

// ---- collectEntries integration ----

func TestCollectEntries_ExcludesVendorAndTests(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "web/app/models/user.rb", "class User < ApplicationRecord\n  def name; end\nend\n")
	writeFile(t, dir, "web/spec/models/user_spec.rb", "RSpec.describe User do\nend\n")
	writeFile(t, dir, "web/vendor/cache/gem.rb", "class Gem; end\n")
	writeFile(t, dir, "go/cmd/runner/main.go", "package main\nfunc Run() {}\n")
	writeFile(t, dir, "go/cmd/runner/main_test.go", "package main\nfunc TestRun(t *testing.T) {}\n")
	writeFile(t, dir, "specifications/system/concept.md", "# Concept\n## Section\n")

	entries := collectEntries(dir, "")

	paths := make(map[string]bool)
	for _, e := range entries {
		paths[e.path] = true
	}

	if paths["web/spec/models/user_spec.rb"] {
		t.Error("spec file should be excluded")
	}
	if paths["web/vendor/cache/gem.rb"] {
		t.Error("vendor file should be excluded")
	}
	if paths["go/cmd/runner/main_test.go"] {
		t.Error("Go test file should be excluded")
	}
	if !paths["web/app/models/user.rb"] {
		t.Error("Ruby model should be included")
	}
	if !paths["go/cmd/runner/main.go"] {
		t.Error("Go source should be included")
	}
	if !paths["specifications/system/concept.md"] {
		t.Error("spec markdown should be included")
	}
}

func TestCollectEntries_FocusFilter(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "web/app/models/user.rb", "class User < ApplicationRecord\n  def name; end\nend\n")
	writeFile(t, dir, "go/cmd/runner/main.go", "package main\nfunc Run() {}\n")

	focus := filepath.Join(dir, "web")
	entries := collectEntries(dir, focus)

	for _, e := range entries {
		if !strings.HasPrefix(e.path, "web/") {
			t.Errorf("focus filter failed: got entry outside focus: %s", e.path)
		}
	}
}

// ---- stripParams ----

func TestStripParams_RemovesParameters(t *testing.T) {
	entries := []*fileEntry{
		{path: "a.rb", content: "  #find_by_id(user_id)\n  .create(email_addr:)\n"},
	}
	result := stripParams(entries)
	if strings.Contains(result[0].content, "user_id") {
		t.Errorf("expected params stripped, got: %s", result[0].content)
	}
	if strings.Contains(result[0].content, "email_addr") {
		t.Errorf("expected params stripped, got: %s", result[0].content)
	}
	if !strings.Contains(result[0].content, "(...)") {
		t.Errorf("expected (...) placeholder, got: %s", result[0].content)
	}
}

// ---- --output flag integration ----

func TestMain_OutputFlag(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "web/app/models/user.rb", "class User < ApplicationRecord\n  def name; end\nend\n")

	outFile := filepath.Join(dir, "REPO_MAP.md")

	// Simulate what main() does
	entries := collectEntries(dir, "")
	rankByRecency(dir, entries)
	output := render(entries, 1024)
	if err := os.WriteFile(outFile, []byte(output), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}

	data, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(data), "# Repo Map") {
		t.Errorf("expected repo map header in output file")
	}
}
