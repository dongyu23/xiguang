package graph

import "xiguang/backend/internal/starmap/domain"

type Builder interface {
	BuildFullGraph(userID int64) (domain.StarGraph, error)
	GetSubGraph(userID, rootFragmentID int64, depth int) (domain.StarGraph, error)
}
