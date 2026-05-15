// Reference parser — walks files, git history, and LEDGER.jsonl to produce a JSON graph.
// Output: JSON to stdout (or --output file), one object with nodes and edges arrays.
// Degrades gracefully on missing inputs — never exits non-zero for missing/malformed data.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ---- Output types ----

type Node struct {
	ID       string         `json:"id"`
	Type     string         `json:"type"`
	Label    string         `json:"label"`
	Path     string         `json:"path,omitempty"`
	Status   string         `json:"status,omitempty"`
	Metadata map[string]any `json:"metadata,omitempty"`
}

type Edge struct {
	From string `json:"from"`
	To   string `json:"to"`
	Type string `json:"type"`
}

type Graph struct {
	GeneratedAt string `json:"generated_at"`
	Nodes       []Node `json:"nodes"`
	Edges       []Edge `json:"edges"`
}

// ---- LEDGER.jsonl types ----

type ledgerEntry struct {
	Ts          string   `json:"ts"`
	Type        string   `json:"type"`
	Ref         string   `json:"ref,omitempty"`
	From        string   `json:"from,omitempty"`
	To          string   `json:"to,omitempty"`
	Sha         string   `json:"sha,omitempty"`
	Reason      string   `json:"reason,omitempty"`
	Path        string   `json:"path,omitempty"`
	Section     string   `json:"section,omitempty"`
	By          string   `json:"by,omitempty"`
	PRNumber    int      `json:"pr_number,omitempty"`
	Branch      string   `json:"branch,omitempty"`
	TaskIDs     []string `json:"task_ids,omitempty"`
	SpecRefs    []string `json:"spec_refs,omitempty"`
	ShaFirst    string   `json:"sha_first,omitempty"`
	ShaLast     string   `json:"sha_last,omitempty"`
	Reviewer    string   `json:"reviewer,omitempty"`
	Verdict     string   `json:"verdict,omitempty"`
	ThreadCount int      `json:"thread_count,omitempty"`
	MergeSha    string   `json:"merge_sha,omitempty"`
}

// ---- Regex patterns ----

var (
	// Plan item: - [ ] 5.2 — Title <!-- status: todo, ... -->
	rePlanItem = regexp.MustCompile(`^- \[([ x])\] (\d+\.\d+) — (.+?)(?:\s+<!--(.+?)-->)?$`)
	// blocked-by in plan item comment
	reBlockedBy = regexp.MustCompile(`blocked-by:\s*([\d.]+)`)
	// spec: tag in RSpec describe
	reSpecTag = regexp.MustCompile(`RSpec\.describe\s+[^,\n]+,\s+spec:\s+"([^"]+)"`)
	// markdown links to .md files
	reMdLink = regexp.MustCompile(`\[([^\]]+)\]\(([^)]+\.md[^)]*)\)`)
	// frontmatter block
	reFrontmatter = regexp.MustCompile(`(?s)^---\n(.+?)\n---`)
	// frontmatter key: value
	reFmKey = regexp.MustCompile(`^(\w[\w-]*):\s*(.+)$`)
)

// ---- Parser state ----

type parser struct {
	root   string
	nodes  []Node
	edges  []Edge
	nodeIDs map[string]bool
}

func newParser(root string) *parser {
	return &parser{
		root:    root,
		nodes:   []Node{},
		edges:   []Edge{},
		nodeIDs: map[string]bool{},
	}
}

func (p *parser) addNode(n Node) {
	if p.nodeIDs[n.ID] {
		return
	}
	p.nodeIDs[n.ID] = true
	p.nodes = append(p.nodes, n)
}

func (p *parser) addEdge(from, to, edgeType string) {
	if from == "" || to == "" || from == to {
		return
	}
	p.edges = append(p.edges, Edge{From: from, To: to, Type: edgeType})
}

// ---- Spec file parsing ----

func (p *parser) parseSpecFiles() {
	specsDir := filepath.Join(p.root, "specifications")
	if _, err := os.Stat(specsDir); os.IsNotExist(err) {
		log.Printf("reference-parser: specifications/ not found, skipping spec parsing")
		return
	}

	err := filepath.Walk(specsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}
		rel, _ := filepath.Rel(p.root, path)
		p.parseSpecFile(rel)
		return nil
	})
	if err != nil {
		log.Printf("reference-parser: error walking specifications/: %v", err)
	}
}

func (p *parser) parseSpecFile(relPath string) {
	data, err := os.ReadFile(filepath.Join(p.root, relPath))
	if err != nil {
		log.Printf("reference-parser: cannot read %s: %v", relPath, err)
		return
	}
	content := string(data)

	// Determine node type from frontmatter kind
	kind := frontmatterValue(content, "kind")
	name := frontmatterValue(content, "name")
	label := name
	if label == "" {
		label = filepath.Base(relPath)
	}

	nodeType := "spec_section"
	if kind == "research" {
		nodeType = "research_finding"
	}

	nodeID := "spec:" + relPath
	p.addNode(Node{
		ID:    nodeID,
		Type:  nodeType,
		Label: label,
		Path:  relPath,
	})

	// Extract markdown links to other spec files → contains edges
	for _, m := range reMdLink.FindAllStringSubmatch(content, -1) {
		target := m[2]
		// Strip anchor
		if idx := strings.Index(target, "#"); idx >= 0 {
			target = target[:idx]
		}
		// Resolve relative path
		if !strings.HasPrefix(target, "specifications/") {
			dir := filepath.Dir(relPath)
			target = filepath.Join(dir, target)
		}
		targetID := "spec:" + target
		p.addEdge(nodeID, targetID, "contains")
	}
}

func frontmatterValue(content, key string) string {
	m := reFrontmatter.FindStringSubmatch(content)
	if m == nil {
		return ""
	}
	scanner := bufio.NewScanner(strings.NewReader(m[1]))
	for scanner.Scan() {
		line := scanner.Text()
		kv := reFmKey.FindStringSubmatch(line)
		if kv != nil && kv[1] == key {
			return strings.TrimSpace(kv[2])
		}
	}
	return ""
}

// ---- Plan item parsing ----

func (p *parser) parsePlanItems() {
	planPath := filepath.Join(p.root, "IMPLEMENTATION_PLAN.md")
	data, err := os.ReadFile(planPath)
	if err != nil {
		log.Printf("reference-parser: IMPLEMENTATION_PLAN.md not found: %v", err)
		return
	}

	// Track titles for rename detection: title → first ref seen
	titleToRef := map[string]string{}

	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := scanner.Text()
		m := rePlanItem.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		checked := m[1] == "x"
		ref := m[2]
		title := strings.TrimSpace(m[3])
		comment := m[4]

		status := "todo"
		if checked {
			status = "done"
		}
		// Override status from comment if present
		if strings.Contains(comment, "status: in_progress") {
			status = "in_progress"
		} else if strings.Contains(comment, "status: blocked") {
			status = "blocked"
		}

		nodeID := "beat:" + ref
		p.addNode(Node{
			ID:     nodeID,
			Type:   "beat",
			Label:  title,
			Status: status,
		})

		// Rename detection: same title, different ref
		normalTitle := strings.ToLower(title)
		if prior, ok := titleToRef[normalTitle]; ok && prior != ref {
			p.addEdge("beat:"+ref, "beat:"+prior, "renamed_from")
		} else {
			titleToRef[normalTitle] = ref
		}

		// blocked-by edges
		if comment != "" {
			for _, bm := range reBlockedBy.FindAllStringSubmatch(comment, -1) {
				p.addEdge(nodeID, "beat:"+bm[1], "depends_on")
			}
		}

		// spec: reference in comment
		if comment != "" {
			for _, part := range strings.Split(comment, ",") {
				part = strings.TrimSpace(part)
				if strings.HasPrefix(part, "spec:") {
					specRef := strings.TrimSpace(strings.TrimPrefix(part, "spec:"))
					p.addEdge(nodeID, "spec:"+specRef, "refs")
				}
			}
		}
	}
}

// ---- RSpec test file parsing ----

func (p *parser) parseTestFiles() {
	specDir := filepath.Join(p.root, "web", "spec")
	if _, err := os.Stat(specDir); os.IsNotExist(err) {
		log.Printf("reference-parser: web/spec/ not found, skipping test parsing")
		return
	}

	err := filepath.Walk(specDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(path, "_spec.rb") {
			return nil
		}
		rel, _ := filepath.Rel(p.root, path)
		p.parseTestFile(rel)
		return nil
	})
	if err != nil {
		log.Printf("reference-parser: error walking web/spec/: %v", err)
	}
}

func (p *parser) parseTestFile(relPath string) {
	data, err := os.ReadFile(filepath.Join(p.root, relPath))
	if err != nil {
		log.Printf("reference-parser: cannot read %s: %v", relPath, err)
		return
	}

	nodeID := "test:" + relPath
	p.addNode(Node{
		ID:    nodeID,
		Type:  "test_suite",
		Label: filepath.Base(relPath),
		Path:  relPath,
	})

	// spec: tags → refs edges
	for _, m := range reSpecTag.FindAllStringSubmatch(string(data), -1) {
		specRef := m[1]
		p.addEdge(nodeID, "spec:"+specRef, "refs")
	}
}

// ---- LEDGER.jsonl parsing ----

func (p *parser) parseLedger() {
	ledgerPath := filepath.Join(p.root, "LEDGER.jsonl")
	data, err := os.ReadFile(ledgerPath)
	if err != nil {
		log.Printf("reference-parser: LEDGER.jsonl not found: %v", err)
		return
	}

	// Collect PR events by number for assembly
	prOpened := map[int]ledgerEntry{}
	prReviews := map[int][]ledgerEntry{}
	prMerged := map[int]ledgerEntry{}

	scanner := bufio.NewScanner(bytes.NewReader(data))
	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := scanner.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var entry ledgerEntry
		if err := json.Unmarshal(line, &entry); err != nil {
			log.Printf("reference-parser: LEDGER.jsonl line %d malformed: %v", lineNum, err)
			continue
		}

		switch entry.Type {
		case "status":
			// Update beat status if we have the node
			if entry.Ref != "" && entry.To != "" {
				beatID := "beat:" + entry.Ref
				for i, n := range p.nodes {
					if n.ID == beatID {
						p.nodes[i].Status = entry.To
						break
					}
				}
			}
		case "pr_opened":
			prOpened[entry.PRNumber] = entry
		case "pr_review":
			prReviews[entry.PRNumber] = append(prReviews[entry.PRNumber], entry)
		case "pr_merged":
			prMerged[entry.PRNumber] = entry
		}
	}

	// Build PR nodes and edges
	for num, opened := range prOpened {
		prID := fmt.Sprintf("pr:%d", num)
		state := "open"
		if _, merged := prMerged[num]; merged {
			state = "merged"
		}

		p.addNode(Node{
			ID:    prID,
			Type:  "pull_request",
			Label: fmt.Sprintf("PR #%d (%s)", num, opened.Branch),
			Metadata: map[string]any{
				"branch":    opened.Branch,
				"state":     state,
				"sha_first": opened.ShaFirst,
				"sha_last":  opened.ShaLast,
			},
		})

		// PR → beat: implements
		for _, taskID := range opened.TaskIDs {
			p.addEdge(prID, "beat:"+taskID, "implements")
		}
		// PR → spec: addresses
		for _, specRef := range opened.SpecRefs {
			p.addEdge(prID, "spec:"+specRef, "addresses")
		}

		// Review nodes
		for _, review := range prReviews[num] {
			ts := review.Ts
			// Parse epoch from ts for stable ID
			epoch := int64(0)
			if t, err := time.Parse(time.RFC3339, ts); err == nil {
				epoch = t.Unix()
			}
			reviewID := fmt.Sprintf("review:%d:%s:%d", num, review.Reviewer, epoch)
			p.addNode(Node{
				ID:    reviewID,
				Type:  "review",
				Label: fmt.Sprintf("Review by %s on PR #%d", review.Reviewer, num),
				Metadata: map[string]any{
					"verdict":      review.Verdict,
					"thread_count": review.ThreadCount,
				},
			})
			p.addEdge(reviewID, prID, "reviews")
		}

		// PR → merge commit
		if merged, ok := prMerged[num]; ok && merged.MergeSha != "" {
			sha7 := merged.MergeSha
			if len(sha7) > 7 {
				sha7 = sha7[:7]
			}
			p.addEdge(prID, "commit:"+sha7, "contains")
		}
	}
}

// ---- Git log parsing ----

func (p *parser) parseGitLog() {
	out, err := runGit(p.root, "log", "--format=%H|%s|%ai", "HEAD")
	if err != nil {
		log.Printf("reference-parser: git log failed: %v", err)
		return
	}

	scanner := bufio.NewScanner(strings.NewReader(out))
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, "|", 3)
		if len(parts) < 2 {
			continue
		}
		sha := parts[0]
		subject := parts[1]
		if len(sha) < 7 {
			continue
		}
		sha7 := sha[:7]
		p.addNode(Node{
			ID:    "commit:" + sha7,
			Type:  "commit",
			Label: subject,
			Metadata: map[string]any{
				"sha": sha,
			},
		})
	}
}

func runGit(root string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = root
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// ---- Main ----

func main() {
	root := flag.String("root", ".", "project root directory")
	output := flag.String("output", "", "output file path (default: stdout)")
	pretty := flag.Bool("pretty", false, "pretty-print JSON")
	flag.Parse()

	absRoot, err := filepath.Abs(*root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "reference-parser: invalid root: %v\n", err)
		os.Exit(1)
	}
	if _, err := os.Stat(absRoot); err != nil {
		fmt.Fprintf(os.Stderr, "reference-parser: root not found: %s\n", absRoot)
		os.Exit(1)
	}

	p := newParser(absRoot)
	p.parseSpecFiles()
	p.parsePlanItems()
	p.parseTestFiles()
	p.parseLedger()
	p.parseGitLog()

	graph := Graph{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Nodes:       p.nodes,
		Edges:       p.edges,
	}

	var out []byte
	if *pretty {
		out, err = json.MarshalIndent(graph, "", "  ")
	} else {
		out, err = json.Marshal(graph)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "reference-parser: JSON marshal failed: %v\n", err)
		os.Exit(1)
	}

	if *output != "" {
		if err := os.WriteFile(*output, out, 0644); err != nil {
			fmt.Fprintf(os.Stderr, "reference-parser: write failed: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Println(string(out))
	}
}
