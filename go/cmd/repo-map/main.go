// repo-map — generates a token-budgeted markdown summary of the codebase.
// Extracts Ruby class/method signatures, Go exported symbols, and spec headings.
// Uses regex parsing (no CGO, no tree-sitter) to stay compatible with CGO_ENABLED=0.
//
// Usage:
//
//	go/bin/repo-map [--budget N] [--focus dir] [--output file] [--root dir]
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// ---- Flags ----

var (
	flagBudget = flag.Int("budget", 1024, "token budget (1 token ≈ 4 chars)")
	flagFocus  = flag.String("focus", "", "limit output to files under this directory")
	flagOutput = flag.String("output", "", "write to file instead of stdout")
	flagRoot   = flag.String("root", ".", "project root directory")
)

// ---- Regex patterns ----

var (
	// Ruby: module/class declaration (captures nesting keyword and name)
	reRubyClass = regexp.MustCompile(`^(\s*)(module|class)\s+([A-Z][A-Za-z0-9:_]*)(?:\s*<\s*([A-Za-z0-9:_]+))?`)
	// Ruby: public method definition (def, not private/protected)
	reRubyDef = regexp.MustCompile(`^(\s*)def\s+(self\.)?([a-z_][A-Za-z0-9_?!]*)(\([^)]*\))?`)
	// Ruby: private/protected marker (methods after this are excluded)
	reRubyPrivate = regexp.MustCompile(`^\s*(private|protected)\s*$`)
	// Ruby: include/extend concern
	reRubyConcern = regexp.MustCompile(`^\s*(include|extend|prepend)\s+([A-Z][A-Za-z0-9:_]*)`)

	// Go: package declaration
	reGoPackage = regexp.MustCompile(`^package\s+(\w+)`)
	// Go: exported function/method signature
	reGoFunc = regexp.MustCompile(`^func\s+(\([^)]+\)\s+)?([A-Z][A-Za-z0-9_]*)(\([^)]*\))`)
	// Go: exported type declaration
	reGoType = regexp.MustCompile(`^type\s+([A-Z][A-Za-z0-9_]*)\s+`)

	// Markdown: frontmatter description
	reMdDescription = regexp.MustCompile(`^description:\s*(.+)`)
	// Markdown: heading
	reMdHeading = regexp.MustCompile(`^(#{1,2})\s+(.+)`)
	// Markdown: frontmatter fence
	reMdFrontmatter = regexp.MustCompile(`^---\s*$`)
)

// ---- File entry ----

type fileEntry struct {
	path    string // relative to root
	content string // rendered map section
	recency int    // git recency rank (lower = more recent)
}

// ---- Main ----

func main() {
	flag.Parse()

	root, err := filepath.Abs(*flagRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "repo-map: bad root: %v\n", err)
		os.Exit(1)
	}

	focus := ""
	if *flagFocus != "" {
		focus, err = filepath.Abs(*flagFocus)
		if err != nil {
			fmt.Fprintf(os.Stderr, "repo-map: bad focus: %v\n", err)
			os.Exit(1)
		}
	}

	entries := collectEntries(root, focus)
	rankByRecency(root, entries)
	output := render(entries, *flagBudget)

	if *flagOutput != "" {
		if err := os.WriteFile(*flagOutput, []byte(output), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "repo-map: write %s: %v\n", *flagOutput, err)
			os.Exit(1)
		}
	} else {
		fmt.Print(output)
	}
}

// ---- Collection ----

func collectEntries(root, focus string) []*fileEntry {
	var entries []*fileEntry

	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil // skip unreadable
		}
		if d.IsDir() {
			if shouldSkipDir(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}

		rel, _ := filepath.Rel(root, path)

		// Apply focus filter
		if focus != "" && !strings.HasPrefix(path, focus) {
			return nil
		}

		// Skip test files
		if isTestFile(rel) {
			return nil
		}

		var content string
		switch {
		case strings.HasSuffix(path, ".rb"):
			content = parseRuby(path, rel)
		case strings.HasSuffix(path, ".go"):
			content = parseGo(path, rel)
		case strings.HasSuffix(path, ".md") && strings.HasPrefix(rel, "specifications/"):
			content = parseMarkdown(path, rel)
		}

		if content != "" {
			entries = append(entries, &fileEntry{path: rel, content: content})
		}
		return nil
	})

	return entries
}

func shouldSkipDir(name string) bool {
	switch name {
	case "vendor", "node_modules", ".git", "tmp", "log", "public",
		"coverage", "bin", "storage", ".bundle":
		return true
	}
	return false
}

func isTestFile(rel string) bool {
	return strings.Contains(rel, "_spec.rb") ||
		strings.Contains(rel, "_test.go") ||
		strings.Contains(rel, "/spec/") ||
		strings.Contains(rel, "/test/")
}

// ---- Ruby parser ----

func parseRuby(path, rel string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	type classFrame struct {
		name    string
		parent  string
		indent  int
		private bool
	}

	var lines []string
	var stack []classFrame
	var concerns []string
	isPrivate := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		// Track private/protected boundary
		if reRubyPrivate.MatchString(line) {
			isPrivate = true
			continue
		}

		// Class/module declaration
		if m := reRubyClass.FindStringSubmatch(line); m != nil {
			indent := len(m[1])
			// Pop stack frames with deeper or equal indent (new class at same level)
			for len(stack) > 0 && stack[len(stack)-1].indent >= indent {
				stack = stack[:len(stack)-1]
			}
			name := m[3]
			parent := m[4]
			// Build qualified name from stack
			if len(stack) > 0 {
				name = stack[len(stack)-1].name + "::" + name
			}
			stack = append(stack, classFrame{name: name, parent: parent, indent: indent})
			isPrivate = false

			sig := name
			if parent != "" {
				sig += " < " + parent
			}
			lines = append(lines, sig)
			continue
		}

		// Concern inclusions
		if m := reRubyConcern.FindStringSubmatch(line); m != nil {
			concerns = append(concerns, fmt.Sprintf("  %s %s", m[1], m[2]))
			continue
		}

		// Method definitions (public only)
		if !isPrivate {
			if m := reRubyDef.FindStringSubmatch(line); m != nil {
				receiver := m[2] // "self." or ""
				name := m[3]
				params := m[4]
				prefix := "  #"
				if receiver == "self." {
					prefix = "  ."
				}
				sig := prefix + name
				if params != "" {
					sig += params
				}
				lines = append(lines, sig)
			}
		}
	}

	if len(lines) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## " + rel + "\n\n")
	for _, l := range lines {
		sb.WriteString(l + "\n")
	}
	for _, c := range concerns {
		sb.WriteString(c + "\n")
	}
	sb.WriteString("\n")
	return sb.String()
}

// ---- Go parser ----

func parseGo(path, rel string) string {
	// Skip test files (already filtered, but double-check)
	if strings.HasSuffix(path, "_test.go") {
		return ""
	}

	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	var pkg string
	var syms []string

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		if pkg == "" {
			if m := reGoPackage.FindStringSubmatch(line); m != nil {
				pkg = m[1]
				continue
			}
		}

		if m := reGoFunc.FindStringSubmatch(line); m != nil {
			receiver := strings.TrimSpace(m[1])
			name := m[2]
			params := m[3]
			if receiver != "" {
				// Extract receiver type name (skip variable name, get type)
				// receiver looks like "(s *Server)" or "(s Server)"
				recvType := regexp.MustCompile(`\*?([A-Z][A-Za-z0-9_]*)`).FindStringSubmatch(receiver)
				if recvType != nil {
					syms = append(syms, fmt.Sprintf("  func (%s) %s%s", recvType[1], name, params))
				}
			} else {
				syms = append(syms, fmt.Sprintf("  func %s%s", name, params))
			}
			continue
		}

		if m := reGoType.FindStringSubmatch(line); m != nil {
			syms = append(syms, fmt.Sprintf("  type %s", m[1]))
		}
	}

	if pkg == "" || len(syms) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## " + rel + "\n\n")
	sb.WriteString("package " + pkg + "\n")
	for _, s := range syms {
		sb.WriteString(s + "\n")
	}
	sb.WriteString("\n")
	return sb.String()
}

// ---- Markdown parser ----

func parseMarkdown(path, rel string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	var description string
	var headings []string
	inFrontmatter := false
	frontmatterDone := false
	fenceCount := 0

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		// Frontmatter detection
		if !frontmatterDone && reMdFrontmatter.MatchString(line) {
			fenceCount++
			if fenceCount == 1 {
				inFrontmatter = true
				continue
			} else if fenceCount == 2 {
				inFrontmatter = false
				frontmatterDone = true
				continue
			}
		}

		if inFrontmatter {
			if m := reMdDescription.FindStringSubmatch(line); m != nil {
				description = strings.TrimSpace(m[1])
			}
			continue
		}

		// H1 and H2 headings only
		if m := reMdHeading.FindStringSubmatch(line); m != nil {
			level := len(m[1])
			if level <= 2 {
				headings = append(headings, m[1]+" "+m[2])
			}
		}
	}

	if len(headings) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("## " + rel)
	if description != "" {
		sb.WriteString(" — " + description)
	}
	sb.WriteString("\n\n")
	for _, h := range headings {
		sb.WriteString("  " + h + "\n")
	}
	sb.WriteString("\n")
	return sb.String()
}

// ---- Recency ranking ----

// rankByRecency orders entries by git modification recency (most recent first).
// Falls back to alphabetical order if git is unavailable.
func rankByRecency(root string, entries []*fileEntry) {
	// Ask git for files ordered by commit date
	cmd := exec.Command("git", "-C", root, "log", "--name-only", "--pretty=format:", "--diff-filter=AM")
	out, err := cmd.Output()
	if err != nil {
		// No git — sort alphabetically for determinism
		sort.Slice(entries, func(i, j int) bool {
			return entries[i].path < entries[j].path
		})
		return
	}

	rank := make(map[string]int)
	pos := 0
	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		if _, seen := rank[line]; !seen {
			rank[line] = pos
			pos++
		}
	}

	for _, e := range entries {
		if r, ok := rank[e.path]; ok {
			e.recency = r
		} else {
			e.recency = pos // unseen files go last
		}
	}

	sort.Slice(entries, func(i, j int) bool {
		if entries[i].recency != entries[j].recency {
			return entries[i].recency < entries[j].recency
		}
		return entries[i].path < entries[j].path
	})
}

// ---- Rendering with budget ----

// approxTokens estimates token count: 1 token ≈ 4 characters.
func approxTokens(s string) int {
	return (len(s) + 3) / 4
}

// render applies the budget degradation rules from the concept spec:
//  1. Drop method parameters
//  2. Drop H2 headings from specs
//  3. Drop unchanged files (keep only files modified in last 20 commits)
//  4. Drop Go internals (keep only cmd/ entry points)
func render(entries []*fileEntry, budget int) string {
	header := "# Repo Map\n\n"
	budgetChars := budget * 4

	// Pass 1: full fidelity
	body := buildBody(entries)
	if approxTokens(header+body) <= budget {
		return header + body
	}

	// Pass 2: drop method parameters
	stripped := stripParams(entries)
	body = buildBody(stripped)
	if approxTokens(header+body) <= budget {
		return header + body
	}

	// Pass 3: drop H2 headings from markdown entries
	noH2 := dropH2(stripped)
	body = buildBody(noH2)
	if approxTokens(header+body) <= budget {
		return header + body
	}

	// Pass 4: keep only recently changed files (first 20 by recency rank)
	recent := entries
	if len(recent) > 20 {
		recent = recent[:20]
	}
	noH2Recent := dropH2(stripParams(recent))
	body = buildBody(noH2Recent)
	if approxTokens(header+body) <= budget {
		return header + body
	}

	// Pass 5: drop Go non-cmd files
	filtered := filterGoCmd(noH2Recent)
	body = buildBody(filtered)
	if approxTokens(header+body) <= budget {
		return header + body
	}

	// Hard truncate at budget
	_ = budgetChars
	runes := []rune(header + body)
	if len(runes)*4 > budgetChars {
		runes = runes[:budgetChars/4]
	}
	return string(runes)
}

func buildBody(entries []*fileEntry) string {
	var sb strings.Builder
	for _, e := range entries {
		sb.WriteString(e.content)
	}
	return sb.String()
}

// stripParams removes parameter lists from method/function signatures.
func stripParams(entries []*fileEntry) []*fileEntry {
	reParams := regexp.MustCompile(`\([^)]*\)`)
	result := make([]*fileEntry, len(entries))
	for i, e := range entries {
		stripped := reParams.ReplaceAllString(e.content, "(...)")
		result[i] = &fileEntry{path: e.path, content: stripped, recency: e.recency}
	}
	return result
}

// dropH2 removes H2 headings from markdown spec entries.
func dropH2(entries []*fileEntry) []*fileEntry {
	reH2Line := regexp.MustCompile(`(?m)^  ## .+\n`)
	result := make([]*fileEntry, len(entries))
	for i, e := range entries {
		content := e.content
		if strings.HasPrefix(e.path, "specifications/") {
			content = reH2Line.ReplaceAllString(content, "")
		}
		result[i] = &fileEntry{path: e.path, content: content, recency: e.recency}
	}
	return result
}

// filterGoCmd keeps only Go files under cmd/ directories.
func filterGoCmd(entries []*fileEntry) []*fileEntry {
	var result []*fileEntry
	for _, e := range entries {
		if strings.HasSuffix(e.path, ".go") && !strings.Contains(e.path, "/cmd/") {
			continue
		}
		result = append(result, e)
	}
	return result
}
