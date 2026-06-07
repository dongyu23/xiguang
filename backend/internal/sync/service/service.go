package service

import (
	"context"
	"fmt"
	"log/slog"

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
		var rev int64
		var err error
		// Fragment 操作使用事务化方法（entity + oplog 在同一事务中）
		if op.EntityType == "fragment" {
			rev, err = s.repo.PushFragmentOp(ctx, userID, req.DeviceID, op)
		} else {
			if execErr := s.executeEntityOp(ctx, userID, op); execErr != nil {
				slog.Warn("sync push: entity op failed", "client_op_id", op.ClientOpID, "entity_type", op.EntityType, "op_type", op.OpType, "err", execErr)
				results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
				continue
			}
			rev, err = s.repo.InsertOperation(ctx, userID, req.DeviceID, op)
		}
		if err != nil {
			slog.Warn("sync push: op failed", "client_op_id", op.ClientOpID, "err", err)
			results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
			continue
		}
		newRev = rev
		results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "applied", ServerRev: rev})
	}
	return domain.PushResponse{Results: results, NewServerRev: newRev}
}

func (s *Service) executeEntityOp(ctx context.Context, userID int64, op domain.PushOperation) error {
	switch op.EntityType {
	case "fragment":
		return s.executeFragmentOp(ctx, userID, op)
	default:
		return nil
	}
}

func (s *Service) executeFragmentOp(ctx context.Context, userID int64, op domain.PushOperation) error {
	switch op.OpType {
	case "INSERT":
		_, err := s.repo.ExecuteFragmentInsert(ctx, userID, op.Payload)
		return err
	case "UPDATE":
		entityID, err := s.repo.FindFragmentByPublicID(ctx, userID, op.EntityPublicID)
		if err != nil {
			return fmt.Errorf("find fragment by public_id %s: %w", op.EntityPublicID, err)
		}
		return s.repo.ExecuteFragmentUpdate(ctx, userID, entityID, op.Payload)
	case "DELETE":
		entityID, err := s.repo.FindFragmentByPublicID(ctx, userID, op.EntityPublicID)
		if err != nil {
			return fmt.Errorf("find fragment by public_id %s: %w", op.EntityPublicID, err)
		}
		return s.repo.ExecuteFragmentDelete(ctx, userID, entityID)
	default:
		return nil
	}
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
	hasMore := len(items) >= 100
	return domain.PullResponse{
		Operations:       items,
		NextSinceRev:     nextRev,
		HasMore:          hasMore,
		FullSyncRequired: false,
	}, nil
}

func (s *Service) Status(ctx context.Context, userID int64) (domain.SyncStatus, error) {
	rev, err := s.repo.FindMostRecentServerRev(ctx, userID)
	if err != nil {
		return domain.SyncStatus{}, err
	}
	return domain.SyncStatus{
		ServerRev: rev,
		Connected: true,
	}, nil
}
