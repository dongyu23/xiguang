package rules

const (
	StarPointThreshold = 3
	FormedThreshold    = 5
	DormantDays        = 30
)

// StatusForFragmentCount returns the island status purely based on fragment count.
// This is the single source of truth for count→status mapping used across the codebase.
func StatusForFragmentCount(count int) string {
	switch {
	case count >= FormedThreshold:
		return "formed"
	case count > StarPointThreshold:
		return "growing"
	case count >= StarPointThreshold:
		return "star_point"
	default:
		return ""
	}
}

// NextStatus computes the next island status given the current state, new fragment count,
// and whether a new fragment was just added (hasNewActivity).
//
// This implements the full island lifecycle:
//
//	null / ""  + count≥3  → star_point
//	star_point + count≥5  → formed
//	star_point + count=4  → growing
//	formed     + dormant  → dormant (handled externally via CheckDormancy)
//	dormant    + new frag → relit
//	relit      + count≥5  → formed
func NextStatus(currentStatus string, count int, hasNewActivity bool) string {
	base := StatusForFragmentCount(count)
	if base == "" {
		return ""
	}

	switch currentStatus {
	case "dormant":
		if hasNewActivity {
			return "relit"
		}
		return "dormant"
	case "relit":
		if count >= FormedThreshold {
			return "formed"
		}
		return "relit"
	default:
		return base
	}
}

// ShouldBeDormant checks if a formed island with the given last-activity timestamp
// has been quiet long enough to transition to dormant.
func ShouldBeDormant(lastFragmentDaysAgo int) bool {
	return lastFragmentDaysAgo >= DormantDays
}
