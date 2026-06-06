package service

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"xiguang/backend/internal/tag/domain"
	"xiguang/backend/internal/tag/repository"
)

var ErrEmptyName = errors.New("tag_empty")

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID int64, rawPageSize string) (domain.Page, error) {
	pageSize := parsePageSize(rawPageSize, 100)
	items, err := s.repo.List(ctx, userID, pageSize)
	if err != nil {
		return domain.Page{}, err
	}
	return domain.Page{
		Items:      items,
		Page:       1,
		PageSize:   pageSize,
		Total:      len(items),
		TotalPages: 1,
	}, nil
}

func (s *Service) Create(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Tag, error) {
	params.Name = cleanName(params.Name)
	if params.Name == "" {
		return domain.Tag{}, ErrEmptyName
	}
	return s.repo.Create(ctx, userID, params)
}

func (s *Service) Update(ctx context.Context, userID, tagID int64, params domain.UpsertParams) (domain.Tag, error) {
	params.Name = cleanName(params.Name)
	if params.Name == "" {
		return domain.Tag{}, ErrEmptyName
	}
	return s.repo.Update(ctx, userID, tagID, params)
}

func (s *Service) Delete(ctx context.Context, userID, tagID int64) (bool, error) {
	return s.repo.Delete(ctx, userID, tagID)
}

func cleanName(name string) string {
	return strings.TrimSpace(strings.TrimPrefix(name, "#"))
}

func parsePageSize(raw string, fallback int) int {
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 || value > 100 {
		return fallback
	}
	return value
}
