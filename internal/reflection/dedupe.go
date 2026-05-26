package reflection

// FindingKey is a unique key for deduplication.
type FindingKey struct {
	File   string
	Line   uint
	CWE    string
}

// DedupeEngine merges duplicate findings.
type DedupeEngine struct {
	seen map[FindingKey]int
}

// NewDedupeEngine creates a new dedupe engine.
func NewDedupeEngine() *DedupeEngine {
	return &DedupeEngine{seen: make(map[FindingKey]int)}
}

// Check returns false if this finding is a duplicate, or true if it's new.
// If new, it records the finding key.
func (de *DedupeEngine) Check(file string, line uint, cwe string) bool {
	key := FindingKey{File: file, Line: line, CWE: cwe}
	if _, exists := de.seen[key]; exists {
		return false // duplicate
	}
	de.seen[key] = 1
	return true // new
}
