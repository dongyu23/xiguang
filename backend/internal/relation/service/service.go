package service

import (
	"context"
	"errors"
	"strings"

	"xiguang/backend/internal/relation/domain"
	"xiguang/backend/internal/relation/repository"
)

var ErrInvalidRelation = errors.New("invalid_relation")

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Create(ctx context.Context, userID int64, params domain.CreateParams) (domain.Relation, error) {
	params.RelationType = strings.TrimSpace(params.RelationType)
	if params.SourceFragmentID == 0 ||
		params.TargetFragmentID == 0 ||
		params.SourceFragmentID == params.TargetFragmentID ||
		params.RelationType == "" {
		return domain.Relation{}, ErrInvalidRelation
	}
	return s.repo.Create(ctx, userID, params)
}

func (s *Service) List(ctx context.Context, userID, fragmentID int64) ([]domain.Relation, error) {
	return s.repo.List(ctx, userID, fragmentID)
}

func (s *Service) Delete(ctx context.Context, userID, relationID int64) (bool, error) {
	return s.repo.Delete(ctx, userID, relationID)
}
