// Package parser — JavaScript parser fallback (always available, no CGO needed)
//
// When CGO is enabled, parser_ts.go handles c/cpp/python/go/java.
// JavaScript is always parsed via regex since tree-sitter may not have
// the JS grammar compiled in.
//
// This file has NO build tag — it is always compiled.

package parser

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

// JS-specific regex patterns
var jsFuncPattern = regexp.MustCompile(
	`(?m)(?:` +
		`function\s+(\w+)\s*\(|` + // function foo()
		`(\w+)\s*=\s*(?:async\s+)?function\s*\(|` + // foo = function()
		`(\w+)\s*=\s*(?:async\s+)?\([^)]*\)\s*=>|` + // foo = () => {}
		`(\w+)\s*\([^)]*\)\s*\{` + // foo() { (method shorthand)
		`)`,
)

var jsClassPattern = regexp.MustCompile(`(?m)^\s*class\s+(\w+)`)

var jsArrowInObj = regexp.MustCompile(`(?m)(\w+)\s*:\s*(?:async\s+)?\([^)]*\)\s*=>`)

var jsMethodInObj = regexp.MustCompile(`(?m)(\w+)\s*\([^)]*\)\s*\{`)

// JS string literal pattern (double and single quotes, excluding template literals)
var jsStringPattern = regexp.MustCompile(`["']([^"']{4,})["']`)

// JS known dangerous function calls
var jsDangerousCalls = map[string]bool{
	"exec":           true,
	"eval":           true,
	"spawn":          true,
	"fork":           true,
	"require":        true,
	"fetch":          true,
	"process":        true,
	"execSync":       true,
	"execFile":       true,
	"execFileSync":   true,
	"spawnSync":      true,
	"child_process":  true,
	"shelljs":        true,
	"Function":       true,
	"setTimeout":     true,
	"setInterval":    true,
	"unescape":       true,
	"decodeURI":      true,
	"JSON.parse":     true,
	"crypto.createHash": true,
	"crypto.createHmac": true,
}

// JS known safe calls to skip
var jsSafeCallPattern = regexp.MustCompile(`(?i)(console|log|debug|info|warn|error|assert|count|dir|time|timeEnd|describe|it|test|expect|assert|should)\s*\(`)


func parseJSFile(filePath string) (*ParseResult, error) {
	// Guard: skip files >512KB (likely minified bundles)
	fi, err := os.Stat(filePath)
	if err != nil {
		return nil, err
	}
	if fi.Size() > 512*1024 {
		return &ParseResult{
			File:     filePath,
			Language: "javascript",
		}, nil
	}

	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	// Guard: skip minified single-line files (>2000 chars on any line)
	text := string(content)
	lines := strings.Split(text, "\n")
	for _, line := range lines {
		if len(line) > 2000 {
			return &ParseResult{
				File:     filePath,
				Language: "javascript",
			}, nil
		}
	}

	result := &ParseResult{
		File:     filePath,
		Language: "javascript",
	}

	// Extract functions
	seen := make(map[string]bool)
	for _, match := range jsFuncPattern.FindAllStringSubmatch(text, -1) {
		for i := 1; i < len(match); i++ {
			if match[i] != "" && !seen[match[i]] {
				seen[match[i]] = true
				lineNum := findLine(lines, match[0])
				result.Functions = append(result.Functions, FunctionInfo{
					Name:      match[i],
					File:      filePath,
					StartLine: uint(lineNum),
					EndLine:   uint(lineNum + 1),
				})
				break
			}
		}
	}

	// Extract arrow functions in objects
	for _, match := range jsArrowInObj.FindAllStringSubmatch(text, -1) {
		name := match[1]
		if !seen[name] && name != "if" && name != "do" && name != "for" && name != "try" && name != "while" && name != "switch" {
			seen[name] = true
			lineNum := findLine(lines, match[0])
			result.Functions = append(result.Functions, FunctionInfo{
				Name:      name,
				File:      filePath,
				StartLine: uint(lineNum),
				EndLine:   uint(lineNum + 1),
			})
		}
	}

	// Extract method shorthand in objects
	for _, match := range jsMethodInObj.FindAllStringSubmatch(text, -1) {
		name := match[1]
		if !seen[name] && name != "if" && name != "do" && name != "for" && name != "try" && name != "while" && name != "switch" && name != "catch" {
			seen[name] = true
			lineNum := findLine(lines, match[0])
			result.Functions = append(result.Functions, FunctionInfo{
				Name:      name,
				File:      filePath,
				StartLine: uint(lineNum),
				EndLine:   uint(lineNum + 1),
			})
		}
	}

	// Extract classes
	for _, match := range jsClassPattern.FindAllStringSubmatch(text, -1) {
		lineNum := findLine(lines, match[0])
		result.Types = append(result.Types, TypeInfo{
			Name:      match[1],
			Kind:      "class",
			File:      filePath,
			StartLine: uint(lineNum),
		})
	}

	// Extract string literals (S2)
	seenStr := make(map[string]bool)
	for _, match := range jsStringPattern.FindAllStringSubmatch(text, -1) {
		val := match[1]
		if len(val) < 4 || seenStr[val] {
			continue
		}
		seenStr[val] = true
		lineNum := findLine(lines, match[0])
		result.StringLiterals = append(result.StringLiterals, StringLiteral{
			File:    filePath,
			Line:    uint(lineNum),
			Value:   truncate(val, 256),
			Length:  len(val),
			Context: "global",
			Kinds:   inferStringKind(val),
		})
	}

	// Extract known dangerous function calls (S1)
	// Look for patterns like: dangerousFunc(...), obj.dangerousFunc(...)
	for fnName := range jsDangerousCalls {
		// Match both direct calls and method calls
		pattern := regexp.MustCompile(`(?m)(?:` + regexp.QuoteMeta(fnName) + `|\b\w+\.` + regexp.QuoteMeta(fnName) + `)\s*\(([^)]{0,256})\)`)
		for _, match := range pattern.FindAllStringSubmatch(text, -1) {
			lineNum := findLine(lines, match[0])
			args := ""
			if len(match) > 1 {
				args = strings.TrimSpace(match[1])
			}
			result.CallSites = append(result.CallSites, CallSite{
				CallerFunction: "(global)",
				CalleeName:     fnName,
				File:           filePath,
				Line:           uint(lineNum),
				Arguments:      []string{truncate(args, 128)},
				Category:       "generic",
			})
		}
	}

	return result, nil
}

func findLine(lines []string, snippet string) int {
	// Take first line of the snippet for matching
	firstLine := strings.SplitN(snippet, "\n", 2)[0]
	firstLine = strings.TrimSpace(firstLine)
	if len(firstLine) > 80 {
		firstLine = firstLine[:80]
	}

	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.Contains(trimmed, firstLine) || strings.HasPrefix(trimmed, firstLine) {
			return i + 1 // 1-based
		}
	}
	return 1
}

// parseJS is a package-level helper for fallback parsing
func tryParseJS(filePath string) (*ParseResult, error) {
	return parseJSFile(filePath)
}

// Ensure we handle JS parse errors properly
func init() {
	// Verify JS regex compiles correctly at init
	if jsFuncPattern == nil {
		panic("jsFuncPattern failed to compile")
	}
}

// Ensure format string import is used
var _ = fmt.Sprintf
