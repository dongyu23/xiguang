package service

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/repository"
)

var ErrEmptyName = errors.New("island_empty")

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID int64) ([]domain.Island, error) {
	items, err := s.repo.List(ctx, userID)
	if err != nil {
		return nil, err
	}
	for i := range items {
		items[i].ID = items[i].Name
		fillDescription(&items[i])
	}
	return items, nil
}

func (s *Service) Create(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Island, error) {
	params.Name = strings.TrimSpace(params.Name)
	if params.Name == "" {
		return domain.Island{}, ErrEmptyName
	}
	return s.repo.UpsertManual(ctx, userID, params)
}

func (s *Service) Get(ctx context.Context, userID int64, idOrName string) (domain.Island, error) {
	item, err := s.repo.Find(ctx, userID, idOrName)
	if err != nil {
		return domain.Island{}, err
	}
	fillDescription(&item)
	return item, nil
}

func (s *Service) Update(ctx context.Context, userID int64, id int64, params domain.UpsertParams) (domain.Island, error) {
	params.ID = id
	params.Name = strings.TrimSpace(params.Name)
	if params.Name == "" {
		return domain.Island{}, ErrEmptyName
	}
	return s.repo.UpsertManual(ctx, userID, params)
}

func (s *Service) Delete(ctx context.Context, userID, id int64) (bool, error) {
	return s.repo.Delete(ctx, userID, id)
}

func (s *Service) Fragments(ctx context.Context, userID int64, name, rawLimit string) ([]domain.FragmentPreview, error) {
	return s.repo.Fragments(ctx, userID, name, parseLimit(rawLimit, 50))
}

func fillDescription(item *domain.Island) {
	if item.Description == "" && item.Status == "formed" {
		item.Description = "这座小岛已经成形，里面有反复出现的光。"
	}
	if item.Description == "" {
		item.Description = "这个主题星点正在慢慢生长。"
	}
}

func parseLimit(raw string, fallback int) int {
	if raw == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(raw)
	if err != nil || parsed <= 0 || parsed > 100 {
		return fallback
	}
	return parsed
}
