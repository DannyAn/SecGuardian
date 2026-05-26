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
				"weak-crypto-algorithm", "insufficient-key-length"}},
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
// Supports glob-like patterns: "memory.*", "system", "critical"
func MatchFilter(detector string, filter string) bool {
	if filter == "*" || filter == "" || filter == "critical" {
		return true
	}
	ns := strings.SplitN(detector, ".", 2)[0]
	f := strings.TrimSuffix(filter, ".*")
	return ns == f
}
