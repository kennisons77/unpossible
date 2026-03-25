package parser

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

type WorklogEntry struct {
	Timestamp   string `json:"timestamp"`
	Title       string `json:"title"`
	Description string `json:"description"`
}

type Worklog struct {
	Entries []WorklogEntry `json:"entries"`
}

func ParseWorklog(path string) (*Worklog, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening worklog: %w", err)
	}
	defer f.Close()

	var entries []WorklogEntry
	var current *WorklogEntry
	scanner := bufio.NewScanner(f)
	
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		
		if strings.HasPrefix(trimmed, "##") && strings.Contains(trimmed, "—") {
			if current != nil {
				current.Description = strings.TrimSpace(current.Description)
				entries = append(entries, *current)
			}
			
			parts := strings.SplitN(strings.TrimPrefix(trimmed, "##"), "—", 2)
			if len(parts) == 2 {
				timestamp := strings.TrimSpace(parts[0])
				title := strings.TrimSpace(parts[1])
				
				if _, err := time.Parse(time.RFC3339, timestamp); err == nil {
					current = &WorklogEntry{
						Timestamp: timestamp,
						Title:     title,
					}
				}
			}
		} else if current != nil && trimmed != "" && !strings.HasPrefix(trimmed, "#") {
			if current.Description != "" {
				current.Description += "\n"
			}
			current.Description += line
		}
	}
	
	if current != nil {
		current.Description = strings.TrimSpace(current.Description)
		entries = append(entries, *current)
	}
	
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scanning worklog: %w", err)
	}
	
	return &Worklog{Entries: entries}, nil
}
