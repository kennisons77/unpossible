package main

import (
	"encoding/json"
	"os"
	"path/filepath"
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

func findNode(nodes []Node, id string) *Node {
	for i := range nodes {
		if nodes[i].ID == id {
			return &nodes[i]
		}
	}
	return nil
}

func findEdge(edges []Edge, from, to, edgeType string) bool {
	for _, e := range edges {
		if e.From == from && e.To == to && e.Type == edgeType {
			return true
		}
	}
	return false
}

// ---- LEDGER.jsonl parsing ----

func TestParseLedger_StatusUpdatesBeats(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md",
		"- [ ] 1.1 — Some task\n")
	writeFile(t, dir, "LEDGER.jsonl",
		`{"ts":"2026-01-01T00:00:00Z","type":"status","ref":"1.1","from":"todo","to":"done","sha":"abc","reason":"green"}`+"\n")

	p := newParser(dir)
	p.parsePlanItems()
	p.parseLedger()

	n := findNode(p.nodes, "beat:1.1")
	if n == nil {
		t.Fatal("beat:1.1 node not found")
	}
	if n.Status != "done" {
		t.Errorf("expected status done, got %s", n.Status)
	}
}

func TestParseLedger_MalformedLineSkipped(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "LEDGER.jsonl",
		"not json\n"+
			`{"ts":"2026-01-01T00:00:00Z","type":"status","ref":"2.1","from":"todo","to":"in_progress","sha":null,"reason":"ok"}`+"\n")

	p := newParser(dir)
	// Should not panic; malformed line is skipped
	p.parseLedger()
}

func TestParseLedger_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "LEDGER.jsonl", "")

	p := newParser(dir)
	p.parseLedger() // must not panic
	if len(p.nodes) != 0 {
		t.Errorf("expected 0 nodes, got %d", len(p.nodes))
	}
}

func TestParseLedger_PRNodes(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "LEDGER.jsonl",
		`{"ts":"2026-04-17T12:00:00Z","type":"pr_opened","pr_number":42,"branch":"ralph/20260417","task_ids":["3.2"],"spec_refs":["specifications/system/analytics/concept.md"],"sha_first":"abc1234","sha_last":"def5678"}`+"\n"+
			`{"ts":"2026-04-17T14:00:00Z","type":"pr_review","pr_number":42,"reviewer":"ken","verdict":"approved","thread_count":1}`+"\n"+
			`{"ts":"2026-04-17T15:00:00Z","type":"pr_merged","pr_number":42,"merge_sha":"aaa1111bbb"}`+"\n")

	p := newParser(dir)
	p.parseLedger()

	pr := findNode(p.nodes, "pr:42")
	if pr == nil {
		t.Fatal("pr:42 node not found")
	}
	if pr.Metadata["state"] != "merged" {
		t.Errorf("expected state merged, got %v", pr.Metadata["state"])
	}

	// implements edge: pr:42 → beat:3.2
	if !findEdge(p.edges, "pr:42", "beat:3.2", "implements") {
		t.Error("missing implements edge pr:42 → beat:3.2")
	}
	// addresses edge: pr:42 → spec:specifications/system/analytics/concept.md
	if !findEdge(p.edges, "pr:42", "spec:specifications/system/analytics/concept.md", "addresses") {
		t.Error("missing addresses edge")
	}
	// review node exists
	var reviewNode *Node
	for i := range p.nodes {
		if p.nodes[i].Type == "review" {
			reviewNode = &p.nodes[i]
			break
		}
	}
	if reviewNode == nil {
		t.Fatal("review node not found")
	}
	if !findEdge(p.edges, reviewNode.ID, "pr:42", "reviews") {
		t.Error("missing reviews edge")
	}
	// contains edge to merge commit
	if !findEdge(p.edges, "pr:42", "commit:aaa1111", "contains") {
		t.Error("missing contains edge to merge commit")
	}
}

// ---- Plan item parsing ----

func TestParsePlanItems_BasicItem(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md",
		"- [ ] 5.2 — Parser binary\n"+
			"- [x] 4.1 — Research spike\n")

	p := newParser(dir)
	p.parsePlanItems()

	n52 := findNode(p.nodes, "beat:5.2")
	if n52 == nil {
		t.Fatal("beat:5.2 not found")
	}
	if n52.Status != "todo" {
		t.Errorf("expected todo, got %s", n52.Status)
	}
	if n52.Label != "Parser binary" {
		t.Errorf("unexpected label: %s", n52.Label)
	}

	n41 := findNode(p.nodes, "beat:4.1")
	if n41 == nil {
		t.Fatal("beat:4.1 not found")
	}
	if n41.Status != "done" {
		t.Errorf("expected done, got %s", n41.Status)
	}
}

func TestParsePlanItems_BlockedByEdge(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md",
		"- [ ] 6.1 — Spec tags <!-- status: blocked, blocked-by: 5.1 -->\n")

	p := newParser(dir)
	p.parsePlanItems()

	if !findEdge(p.edges, "beat:6.1", "beat:5.1", "depends_on") {
		t.Error("missing depends_on edge beat:6.1 → beat:5.1")
	}
}

func TestParsePlanItems_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md", "# No items\n")

	p := newParser(dir)
	p.parsePlanItems() // must not panic
	if len(p.nodes) != 0 {
		t.Errorf("expected 0 nodes, got %d", len(p.nodes))
	}
}

func TestParsePlanItems_MissingFile(t *testing.T) {
	dir := t.TempDir()
	p := newParser(dir)
	p.parsePlanItems() // must not panic
}

// ---- Spec file parsing ----

func TestParseSpecFiles_NodeCreated(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "specifications/system/analytics/concept.md",
		"---\nname: analytics\nkind: concept\n---\n# Analytics\n")

	p := newParser(dir)
	p.parseSpecFiles()

	n := findNode(p.nodes, "spec:specifications/system/analytics/concept.md")
	if n == nil {
		t.Fatal("spec node not found")
	}
	if n.Type != "spec_section" {
		t.Errorf("expected spec_section, got %s", n.Type)
	}
	if n.Label != "analytics" {
		t.Errorf("expected label analytics, got %s", n.Label)
	}
}

func TestParseSpecFiles_ResearchNodeType(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "specifications/research/foo.md",
		"---\nname: foo\nkind: research\n---\n# Foo\n")

	p := newParser(dir)
	p.parseSpecFiles()

	n := findNode(p.nodes, "spec:specifications/research/foo.md")
	if n == nil {
		t.Fatal("research node not found")
	}
	if n.Type != "research_finding" {
		t.Errorf("expected research_finding, got %s", n.Type)
	}
}

func TestParseSpecFiles_MarkdownLinkEdge(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "specifications/system/foo/concept.md",
		"---\nname: foo\nkind: concept\n---\nSee [bar](../bar/concept.md).\n")
	writeFile(t, dir, "specifications/system/bar/concept.md",
		"---\nname: bar\nkind: concept\n---\n# Bar\n")

	p := newParser(dir)
	p.parseSpecFiles()

	from := "spec:specifications/system/foo/concept.md"
	to := "spec:specifications/system/bar/concept.md"
	if !findEdge(p.edges, from, to, "contains") {
		t.Errorf("missing contains edge %s → %s", from, to)
	}
}

func TestParseSpecFiles_NoSpecsDir(t *testing.T) {
	dir := t.TempDir()
	p := newParser(dir)
	p.parseSpecFiles() // must not panic
}

// ---- RSpec tag parsing ----

func TestParseTestFiles_SpecTagEdge(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "web/spec/models/agents/agent_run_spec.rb",
		`RSpec.describe Agents::AgentRun, spec: "specifications/system/agent-runner/concept.md#agent-run" do
  it "works" do
  end
end
`)

	p := newParser(dir)
	p.parseTestFiles()

	testID := "test:web/spec/models/agents/agent_run_spec.rb"
	n := findNode(p.nodes, testID)
	if n == nil {
		t.Fatal("test node not found")
	}
	if n.Type != "test_suite" {
		t.Errorf("expected test_suite, got %s", n.Type)
	}
	specRef := "specifications/system/agent-runner/concept.md#agent-run"
	if !findEdge(p.edges, testID, "spec:"+specRef, "refs") {
		t.Error("missing refs edge from test to spec")
	}
}

func TestParseTestFiles_NoSpecTag(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "web/spec/models/foo_spec.rb",
		`RSpec.describe Foo do
  it "works" do
  end
end
`)

	p := newParser(dir)
	p.parseTestFiles()

	n := findNode(p.nodes, "test:web/spec/models/foo_spec.rb")
	if n == nil {
		t.Fatal("test node not found")
	}
	// No refs edges expected
	for _, e := range p.edges {
		if e.From == n.ID && e.Type == "refs" {
			t.Errorf("unexpected refs edge: %+v", e)
		}
	}
}

func TestParseTestFiles_NoSpecDir(t *testing.T) {
	dir := t.TempDir()
	p := newParser(dir)
	p.parseTestFiles() // must not panic
}

// ---- Edge deduplication / self-loop prevention ----

func TestAddEdge_SkipsSelfLoop(t *testing.T) {
	p := newParser(t.TempDir())
	p.addEdge("beat:1.1", "beat:1.1", "depends_on")
	if len(p.edges) != 0 {
		t.Error("self-loop edge should be skipped")
	}
}

func TestAddEdge_SkipsEmpty(t *testing.T) {
	p := newParser(t.TempDir())
	p.addEdge("", "beat:1.1", "depends_on")
	p.addEdge("beat:1.1", "", "depends_on")
	if len(p.edges) != 0 {
		t.Error("empty-endpoint edges should be skipped")
	}
}

// ---- Node deduplication ----

func TestAddNode_Deduplication(t *testing.T) {
	p := newParser(t.TempDir())
	p.addNode(Node{ID: "beat:1.1", Type: "beat", Label: "First"})
	p.addNode(Node{ID: "beat:1.1", Type: "beat", Label: "Duplicate"})
	if len(p.nodes) != 1 {
		t.Errorf("expected 1 node, got %d", len(p.nodes))
	}
}

// ---- JSON output ----

func TestGraphOutput_ValidJSON(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md",
		"- [x] 1.1 — Done task\n")
	writeFile(t, dir, "LEDGER.jsonl",
		`{"ts":"2026-01-01T00:00:00Z","type":"status","ref":"1.1","from":"todo","to":"done","sha":null,"reason":"ok"}`+"\n")

	p := newParser(dir)
	p.parsePlanItems()
	p.parseLedger()

	graph := Graph{
		GeneratedAt: "2026-01-01T00:00:00Z",
		Nodes:       p.nodes,
		Edges:       p.edges,
	}
	out, err := json.Marshal(graph)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var roundtrip Graph
	if err := json.Unmarshal(out, &roundtrip); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if len(roundtrip.Nodes) == 0 {
		t.Error("expected nodes in output")
	}
}

// ---- Output file flag ----

func TestMain_OutputFile(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, dir, "IMPLEMENTATION_PLAN.md", "- [ ] 1.1 — Task\n")

	outFile := filepath.Join(dir, "graph.json")

	p := newParser(dir)
	p.parsePlanItems()

	graph := Graph{
		GeneratedAt: "2026-01-01T00:00:00Z",
		Nodes:       p.nodes,
		Edges:       p.edges,
	}
	out, _ := json.Marshal(graph)
	if err := os.WriteFile(outFile, out, 0644); err != nil {
		t.Fatalf("write failed: %v", err)
	}

	data, err := os.ReadFile(outFile)
	if err != nil {
		t.Fatalf("read failed: %v", err)
	}
	var g Graph
	if err := json.Unmarshal(data, &g); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if len(g.Nodes) == 0 {
		t.Error("expected nodes in output file")
	}
}
