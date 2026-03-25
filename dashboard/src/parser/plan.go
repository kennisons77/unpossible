package parser

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Task struct {
	Description string `json:"description"`
	Done        bool   `json:"done"`
}

type Plan struct {
	Tasks []Task `json:"tasks"`
}

func ParseImplementationPlan(path string) (*Plan, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening plan: %w", err)
	}
	defer f.Close()

	var tasks []Task
	scanner := bufio.NewScanner(f)
	
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		
		if strings.HasPrefix(trimmed, "- [x]") {
			desc := strings.TrimSpace(strings.TrimPrefix(trimmed, "- [x]"))
			tasks = append(tasks, Task{Description: desc, Done: true})
		} else if strings.HasPrefix(trimmed, "- [ ]") {
			desc := strings.TrimSpace(strings.TrimPrefix(trimmed, "- [ ]"))
			tasks = append(tasks, Task{Description: desc, Done: false})
		}
	}
	
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scanning plan: %w", err)
	}
	
	return &Plan{Tasks: tasks}, nil
}
