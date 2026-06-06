package graph

type Point struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

func QuadraticControlPoint(source, target Point, offset float64) Point {
	return Point{X: (source.X + target.X) / 2, Y: (source.Y+target.Y)/2 + offset}
}
