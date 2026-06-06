package service

import (
	"context"

	"xiguang/backend/internal/sync/domain"
	"xiguang/backend/internal/sync/repository"
)

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Push(ctx context.Context, userID int64, req domain.PushRequest) domain.PushResponse {
	results := []domain.PushResult{}
	var newRev int64
	for _, op := range req.Operations {
		if op.ClientOpID == "" {
			continue
		}
		rev, err := s.repo.InsertOperation(ctx, userID, req.DeviceID, op)
		if err != nil {
			results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
			continue
		}
		newRev = rev
		results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "accepted", ServerRev: rev})
	}
	return domain.PushResponse{Results: results, NewServerRev: newRev}
}

func (s *Service) Pull(ctx context.Context, userID, sinceRev int64) (domain.PullResponse, error) {
	items, err := s.repo.FindSinceRev(ctx, userID, sinceRev, 100)
	if err != nil {
		return domain.PullResponse{}, err
	}
	nextRev := sinceRev
	if len(items) > 0 {
		nextRev = items[len(items)-1].ServerRev
	}
	return domain.PullResponse{
		Operations:       items,
		NextSinceRev:     nextRev,
		HasMore:          false,
		FullSyncRequired: false,
	}, nil
}
