package domain

import fragmentdomain "xiguang/backend/internal/fragment/domain"

type Fragment = fragmentdomain.Fragment

type Query struct {
	Emotion string
	Tag     string
	Limit   int
}

type DateGroup struct {
	Label     string     `json:"label"`
	Count     int        `json:"count"`
	Fragments []Fragment `json:"fragments"`
}

type Response struct {
	Groups  []DateGroup `json:"groups"`
	Items   []Fragment  `json:"items"`
	HasMore bool        `json:"has_more"`
}
