package graph

func ClampDepth(depth int) int {
	if depth <= 0 {
		return 2
	}
	if depth > 5 {
		return 5
	}
	return depth
}
