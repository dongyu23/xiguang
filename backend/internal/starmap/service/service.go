package service

import (
	"context"
	"math"

	"xiguang/backend/internal/starmap/domain"
	"xiguang/backend/internal/starmap/repository"
)

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Graph(ctx context.Context, userID int64) (domain.StarGraph, error) {
	fragments, err := s.repo.Fragments(ctx, userID, 60)
	if err != nil {
		return domain.StarGraph{}, err
	}
	relations, err := s.repo.Relations(ctx, userID, 120)
	if err != nil {
		return domain.StarGraph{}, err
	}

	nodes := make([]domain.StarNode, 0, len(fragments))
	for i, item := range fragments {
		angle := float64(i) * 0.82
		radius := 120 + float64(i%7)*24
		nodes = append(nodes, domain.StarNode{
			FragmentID: item.ID,
			Label:      shortLabel(item.Text),
			Emotion:    item.Emotion,
			X:          math.Cos(angle) * radius,
			Y:          math.Sin(angle) * radius,
		})
	}

	edges := make([]domain.StarEdge, 0, len(relations))
	for _, item := range relations {
		edges = append(edges, domain.StarEdge{
			SourceID:     item.SourceFragmentID,
			TargetID:     item.TargetFragmentID,
			RelationType: item.RelationType,
			CurveType:    "quadratic",
		})
	}

	return domain.StarGraph{
		Nodes: nodes,
		Edges: edges,
		Metadata: domain.Metadata{
			TotalNodes: len(nodes),
			TotalEdges: len(edges),
		},
	}, nil
}

func shortLabel(text string) string {
	runes := []rune(text)
	if len(runes) <= 20 {
		return text
	}
	return string(runes[:20])
}
