package rules

const (
	StarPointThreshold = 3
	FormedThreshold    = 5
	DormantDays        = 30
)

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
