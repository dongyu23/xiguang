package domain

type FragmentSource struct {
	ID      int64
	Text    string
	Emotion string
}

type RelationSource struct {
	SourceFragmentID int64
	TargetFragmentID int64
	RelationType     string
}

type StarNode struct {
	FragmentID int64   `json:"fragment_id"`
	Label      string  `json:"label"`
	Emotion    string  `json:"emotion"`
	X          float64 `json:"x"`
	Y          float64 `json:"y"`
}

type StarEdge struct {
	SourceID     int64  `json:"source_id"`
	TargetID     int64  `json:"target_id"`
	RelationType string `json:"relation_type"`
	CurveType    string `json:"curve_type"`
}

type Metadata struct {
	TotalNodes int `json:"total_nodes"`
	TotalEdges int `json:"total_edges"`
}

type StarGraph struct {
	Nodes    []StarNode `json:"nodes"`
	Edges    []StarEdge `json:"edges"`
	Metadata Metadata   `json:"metadata"`
}
