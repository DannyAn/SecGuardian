package budget

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Budget contains token budget configuration for different scan types.
type Budget struct {
	MaxPerDetector int `json:"max_per_detector"`  // tokens per single detector execution
	MaxPerScan     int `json:"max_per_scan"`       // tokens per full secguard scan
	MaxPerAudit    int `json:"max_per_audit"`      // tokens per secaudit audit
	MaxPerReview   int `json:"max_per_review"`     // tokens per secreview review
}

// DefaultBudget returns default token budgets.
func DefaultBudget() Budget {
	return Budget{
		MaxPerDetector: 3000,
		MaxPerScan:     8000,
		MaxPerAudit:    15000,
		MaxPerReview:   10000,
	}
}

// EstimateTokens estimates the number of tokens for a given JSON object.
// Rough estimation: 1 token ≈ 4 characters for English text.
func EstimateTokens(v interface{}) int {
	data, err := json.Marshal(v)
	if err != nil {
		return 0
	}
	return len(data) / 4
}

// CheckBudget warns if estimated tokens exceed the budget.
// Returns nil if within budget, or an error with suggestions.
func CheckBudget(estimated int, budget int) error {
	if estimated > budget {
		return fmt.Errorf("token budget exceeded: %d > %d (max). Suggestion: narrow scan scope",
			estimated, budget)
	}
	return nil
}

// CheckFileSize checks if a file is too large to scan efficiently.
// Returns estimated tokens and a warning if over threshold.
func CheckFileSize(path string) (int, string) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, ""
	}

	// Rough: 1 byte ≈ 0.25 tokens
	tokens := int(info.Size()) / 4

	if tokens > 5000 {
		return tokens, fmt.Sprintf("File %s is large (~%d tokens). Consider narrowing scope.",
			filepath.Base(path), tokens)
	}
	return tokens, ""
}

// ScanBudget returns the budget for a given scan command.
func ScanBudget(command string) int {
	b := DefaultBudget()
	switch command {
	case "secguard":
		return b.MaxPerScan
	case "secaudit":
		return b.MaxPerAudit
	case "secreview":
		return b.MaxPerReview
	default:
		return b.MaxPerScan
	}
}

// BudgetSuggestion returns a human-readable suggestion for reducing token usage.
func BudgetSuggestion(estimated int, budget int) string {
	if estimated <= budget {
		return ""
	}
	over := estimated - budget
	return fmt.Sprintf("Estimated %d tokens over budget. Try: (1) narrower path, (2) fewer filters, (3) smaller target file", over)
}
