package reflection

import (
	"os"
	"strings"
)

// PathValidator verifies that a finding's file:line reference exists.
type PathValidator struct{}

// Validate checks that the referenced line exists in the source file.
func (pv *PathValidator) Validate(file string, line uint) (bool, string) {
	content, err := os.ReadFile(file)
	if err != nil {
		return false, "file not found: " + err.Error()
	}
	lines := strings.Split(string(content), "\n")
	if int(line) > len(lines) || line == 0 {
		return false, "line out of range"
	}
	if strings.TrimSpace(lines[line-1]) == "" {
		return false, "line is blank"
	}
	return true, ""
}
