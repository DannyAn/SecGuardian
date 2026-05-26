package reflection

// ConfidenceResult holds the final confidence assessment for a finding.
type ConfidenceResult struct {
	Level   string `json:"level"`   // high, medium, low
	Score   int    `json:"score"`   // 0-100
	Reasons []string `json:"reasons"`
}

// ConfidenceScorer evaluates evidence and produces a confidence score.
type ConfidenceScorer struct{}

// Score evaluates finding evidence and returns a confidence level.
// Algorithm:
//   path_verified (+30), symbol_verified (+30),
//   chain_complete (+20), actionable_remediation (+20)
//   >=80 → high, >=50 → medium, <50 → low
func (cs *ConfidenceScorer) Score(pathVerified bool, symbolVerified bool,
	chainComplete bool, actionableRemediation bool) ConfidenceResult {

	score := 0
	var reasons []string

	if pathVerified {
		score += 30
		reasons = append(reasons, "path_verified")
	}
	if symbolVerified {
		score += 30
		reasons = append(reasons, "symbol_verified")
	}
	if chainComplete {
		score += 20
		reasons = append(reasons, "chain_complete")
	}
	if actionableRemediation {
		score += 20
		reasons = append(reasons, "actionable_remediation")
	}

	level := "low"
	if score >= 80 {
		level = "high"
	} else if score >= 50 {
		level = "medium"
	}

	return ConfidenceResult{
		Level:   level,
		Score:   score,
		Reasons: reasons,
	}
}
