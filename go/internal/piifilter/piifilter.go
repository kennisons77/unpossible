// Package piifilter redacts secrets and PII patterns from event properties
// before they are stored in Postgres. Used by the analytics sidecar and parser.
package piifilter

import "regexp"

// redactPatterns matches common secret and PII patterns.
var redactPatterns = []*regexp.Regexp{
	// API keys and tokens — matches key=value, key: value, and JSON "key": "value"
	regexp.MustCompile(`(?i)(api[_-]?key|token|secret|password|passwd|pwd)["']?\s*[:=]\s*["']?\S+["']?`),
	// AWS access key IDs
	regexp.MustCompile(`AKIA[0-9A-Z]{16}`),
	// Private key headers
	regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----`),
	// Email addresses
	regexp.MustCompile(`[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`),
}

const redacted = "[REDACTED]"

// Redact replaces all matched PII and secret patterns in s with "[REDACTED]".
func Redact(s string) string {
	for _, re := range redactPatterns {
		s = re.ReplaceAllString(s, redacted)
	}
	return s
}
