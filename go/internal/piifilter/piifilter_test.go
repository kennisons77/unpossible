package piifilter_test

import (
	"testing"

	"github.com/unpossible/unpossible/internal/piifilter"
)

func TestRedactAPIKey(t *testing.T) {
	input := `{"api_key": "sk-abc123xyz"}`
	got := piifilter.Redact(input)
	if got == input {
		t.Errorf("expected api_key to be redacted, got: %s", got)
	}
}

func TestRedactAWSKey(t *testing.T) {
	input := "AKIAIOSFODNN7EXAMPLE"
	got := piifilter.Redact(input)
	if got == input {
		t.Errorf("expected AWS key to be redacted, got: %s", got)
	}
}

func TestRedactEmail(t *testing.T) {
	input := "contact [email@example.com] for support"
	got := piifilter.Redact(input)
	if got == input {
		t.Errorf("expected email to be redacted, got: %s", got)
	}
}

func TestRedactCleanInput(t *testing.T) {
	// Invariant: clean input passes through unchanged.
	input := `{"event": "page_view", "url": "/home"}`
	got := piifilter.Redact(input)
	if got != input {
		t.Errorf("expected clean input unchanged, got: %s", got)
	}
}
