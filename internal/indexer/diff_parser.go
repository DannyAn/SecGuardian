package indexer

import (
	"bufio"
	"bytes"
	"os/exec"
	"strings"
)

// DiffFile describes a single changed file from git diff.
type DiffFile struct {
	Path    string   `json:"path"`
	Changes []Change `json:"changes"`
}

// Change describes a single changed line range.
type Change struct {
	StartLine uint `json:"start_line"`
	EndLine   uint `json:"end_line"`
	Type      string `json:"type"` // added, modified
}

// DiffResult holds the parsed git diff output.
type DiffResult struct {
	Files []DiffFile `json:"files"`
}

// ParseGitDiff runs git diff and parses the output into structured changes.
func ParseGitDiff(repoPath string, ref string) (*DiffResult, error) {
	cmd := exec.Command("git", "-C", repoPath, "diff", ref, "--unified=0")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, err
	}

	result := &DiffResult{}
	scanner := bufio.NewScanner(&out)
	var currentFile *DiffFile

	for scanner.Scan() {
		line := scanner.Text()

		if strings.HasPrefix(line, "+++ b/") {
			if currentFile != nil {
				result.Files = append(result.Files, *currentFile)
			}
			path := strings.TrimPrefix(line, "+++ b/")
			currentFile = &DiffFile{Path: path}
		} else if strings.HasPrefix(line, "@@") && currentFile != nil {
			// Parse @@ -old,old +new,new @@
			parts := strings.Split(line, "+")
			if len(parts) >= 2 {
				rangePart := strings.Split(parts[1], " @@")[0]
				rangeParts := strings.Split(rangePart, ",")
				startLine := uint(0)
				if len(rangeParts) >= 1 {
					// Parse the start line number
					// Format: "42" or "42,10"
					lineNum := strings.Split(rangeParts[0], ",")[0]
					if n, err := fmtSscanf(lineNum); err == nil {
						startLine = uint(n)
					}
				}
				endLine := startLine
				if len(rangeParts) >= 2 {
					if count, err := fmtSscanf(rangeParts[1]); err == nil && count > 0 {
						endLine = startLine + uint(count) - 1
					}
				}
				currentFile.Changes = append(currentFile.Changes, Change{
					StartLine: startLine,
					EndLine:   endLine,
					Type:      "modified",
				})
			}
		}
	}

	if currentFile != nil {
		result.Files = append(result.Files, *currentFile)
	}

	return result, nil
}

// AffectedSymbols returns symbol names affected by changes.
// Symbols are "affected" if they overlap with changed line ranges.
func AffectedSymbols(functions []struct{ Name string; StartLine, EndLine uint }, changes []Change) []string {
	var affected []string
	seen := make(map[string]bool)

	for _, fn := range functions {
		for _, ch := range changes {
			if ch.StartLine <= fn.EndLine && ch.EndLine >= fn.StartLine {
				if !seen[fn.Name] {
					affected = append(affected, fn.Name)
					seen[fn.Name] = true
				}
				break
			}
		}
	}
	return affected
}

// Helper — simplified Sscanf since we don't want to import fmt
func fmtSscanf(s string) (int, error) {
	n := 0
	for _, c := range s {
		if c >= '0' && c <= '9' {
			n = n*10 + int(c-'0')
		} else {
			break
		}
	}
	return n, nil
}
