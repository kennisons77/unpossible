package parser

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type SpecFile struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

type SpecList struct {
	Specs []SpecFile `json:"specs"`
}

type SpecContent struct {
	Name    string `json:"name"`
	Content string `json:"content"`
}

func ListSpecs(specsDir string) (*SpecList, error) {
	var specs []SpecFile
	
	err := filepath.Walk(specsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".md") {
			relPath, err := filepath.Rel(specsDir, path)
			if err != nil {
				return err
			}
			specs = append(specs, SpecFile{
				Name: strings.TrimSuffix(relPath, ".md"),
				Path: relPath,
			})
		}
		return nil
	})
	
	if err != nil {
		return nil, fmt.Errorf("walking specs dir: %w", err)
	}
	
	return &SpecList{Specs: specs}, nil
}

func ReadSpec(specsDir, name string) (*SpecContent, error) {
	safeName := filepath.Clean(name)
	if strings.Contains(safeName, "..") {
		return nil, fmt.Errorf("invalid spec name: %s", name)
	}
	
	path := filepath.Join(specsDir, safeName+".md")
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading spec: %w", err)
	}
	
	return &SpecContent{
		Name:    name,
		Content: string(content),
	}, nil
}
