package scheduler

import (
	"sort"
	"strings"
)

// GroupDef defines a group of detectors that share context.
type GroupDef struct {
	Name      string   `json:"name"`
	Detectors []string `json:"detectors"`
}

// DefaultGroups returns the standard analysis groups.
func DefaultGroups() []GroupDef {
	return []GroupDef{
		{Name: "memory",
			Detectors: []string{"null-dereference", "double-free", "use-after-free",
				"memory-leak", "mismatched-free"}},
		{Name: "bounds",
			Detectors: []string{"buffer-overflow", "heap-buffer-overflow",
				"off-by-one", "integer-overflow"}},
		{Name: "concurrency",
			Detectors: []string{"race-condition", "deadlock", "data-race"}},
		{Name: "system",
			Detectors: []string{"command-injection", "path-traversal", "toctou",
				"insecure-temp-file", "symlink-attack", "privilege-escalation"}},
		{Name: "crypto",
			Detectors: []string{"hardcoded-secrets", "weak-random",
				"weak-crypto-algorithm", "insufficient-key-length",
				"aes-ecb-mode", "custom-crypto", "hardcoded-iv",
				"password-storage", "tls-version"}},
		{Name: "web",
			Detectors: []string{"xss", "ssrf", "csrf", "auth-bypass", "idor",
				"xxe", "jwt-misuse", "open-redirect", "missing-authentication",
				"missing-authorization", "unrestricted-upload", "sql-injection",
				"deserialization", "code-injection", "input-validation",
				"resource-exhaustion", "excessive-data-exposure", "mass-assignment",
				"nosql-injection", "prototype-pollution", "ssti"}},
		{Name: "error",
			Detectors: []string{"debug-mode-production", "exception-swallow",
				"log-sensitive-data", "panic-to-client", "stack-trace-leak",
				"unified-error-format"}},
	}
}

// ResolveGroup returns the group name for a given detector.
// If no group matches, returns "ungrouped".
func ResolveGroup(detectorName string) string {
	for _, g := range DefaultGroups() {
		for _, d := range g.Detectors {
			if d == detectorName {
				return g.Name
			}
		}
	}
	return "ungrouped"
}

// Schedule returns detectors in group order (memory first, then bounds, etc.)
// so that shared context is built once per group.
func Schedule(detectorNames []string) []string {
	groups := DefaultGroups()
	groupOrder := make(map[string]int)
	for i, g := range groups {
		groupOrder[g.Name] = i
	}
	groupOrder["ungrouped"] = len(groups)

	sort.Slice(detectorNames, func(i, j int) bool {
		gi := groupOrder[ResolveGroup(detectorNames[i])]
		gj := groupOrder[ResolveGroup(detectorNames[j])]
		return gi < gj
	})
	return detectorNames
}

// MatchFilter checks if a detector name matches a namespace filter pattern.
// Supports:
//   - Wildcard: "*" or "" matches everything
//   - Glob: "memory.*" matches all detectors in the memory namespace
//   - Exact: "memory.null-dereference" matches a single detector
//   - Partial: "sql" matches "web.sql-injection"
//   - Comma-separated: "memory.*,system.*" matches multiple namespaces
func MatchFilter(detector string, filter string) bool {
	if filter == "*" || filter == "" {
		return true
	}
	for _, f := range strings.Split(filter, ",") {
		f = strings.TrimSpace(f)
		if f == "" {
			continue
		}
		// Exact match
		if detector == f {
			return true
		}
		// Glob match: memory.* matches memory.null-dereference
		if strings.HasSuffix(f, ".*") {
			prefix := strings.TrimSuffix(f, ".*")
			if strings.HasPrefix(detector, prefix+".") || detector == prefix {
				return true
			}
			continue
		}
		// Namespace-only match: "memory" matches all "memory.*"
		ns := strings.SplitN(detector, ".", 2)[0]
		if ns == f {
			return true
		}
		// Partial name match: "sql" matches "web.sql-injection"
		if !strings.Contains(f, ".") && !strings.Contains(f, "*") {
			parts := strings.SplitN(detector, ".", 2)
			if len(parts) > 1 && strings.Contains(parts[1], f) {
				return true
			}
		}
	}
	return false
}
