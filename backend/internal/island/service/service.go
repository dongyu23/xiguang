package service

import (
	"context"
	"errors"
	"strconv"
	"strings"

	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/repository"
)

var (
	ErrEmptyName       = errors.New("island_empty")
	ErrNotManualIsland = repository.ErrNotManualIsland
	ErrInvalidGroup    = errors.New("invalid_island_group")
)

type Service struct {
	repo repository.Repository
}

func (s *Service) ListGroups(ctx context.Context, userID int64) ([]domain.IslandGroup, error) {
	return s.repo.ListGroups(ctx, userID)
}
func (s *Service) CreateGroup(ctx context.Context, userID int64, params domain.GroupUpsertParams) (domain.IslandGroup, error) {
	params.Name = strings.TrimSpace(params.Name)
	params.Description = strings.TrimSpace(params.Description)
	if params.Name == "" || len(params.IslandIDs) < 2 || len(params.IslandIDs) > 5 {
		return domain.IslandGroup{}, ErrInvalidGroup
	}
	if params.Source != "ai" {
		params.Source = "manual"
	}
	return s.repo.CreateGroup(ctx, userID, params)
}
func (s *Service) GetGroup(ctx context.Context, userID, groupID int64) (domain.IslandGroup, error) {
	return s.repo.FindGroup(ctx, userID, groupID)
}
func (s *Service) UpdateGroup(ctx context.Context, userID, groupID int64, params domain.GroupUpsertParams) (domain.IslandGroup, error) {
	params.Name = strings.TrimSpace(params.Name)
	if params.Name == "" {
		return domain.IslandGroup{}, ErrInvalidGroup
	}
	return s.repo.UpdateGroup(ctx, userID, groupID, params)
}
func (s *Service) DeleteGroup(ctx context.Context, userID, groupID int64) (bool, error) {
	return s.repo.DeleteGroup(ctx, userID, groupID)
}
func (s *Service) AddGroupIslands(ctx context.Context, userID, groupID int64, ids []int64) (domain.IslandGroup, error) {
	if len(ids) == 0 || len(ids) > 5 {
		return domain.IslandGroup{}, ErrInvalidGroup
	}
	return s.repo.AddGroupIslands(ctx, userID, groupID, ids)
}
func (s *Service) RemoveGroupIslands(ctx context.Context, userID, groupID int64, ids []int64) (domain.IslandGroup, error) {
	if len(ids) == 0 {
		return domain.IslandGroup{}, ErrInvalidGroup
	}
	return s.repo.RemoveGroupIslands(ctx, userID, groupID, ids)
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) List(ctx context.Context, userID int64) ([]domain.Island, error) {
	_, _ = s.repo.MarkDormantIslands(ctx, userID)

	items, err := s.repo.List(ctx, userID)
	if err != nil {
		return nil, err
	}
	for i := range items {
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

func (s *Service) AddFragments(ctx context.Context, userID int64, islandID int64, fragmentIDs []int64) (domain.Island, error) {
	return s.repo.AddFragments(ctx, userID, islandID, fragmentIDs)
}

func (s *Service) RemoveFragments(ctx context.Context, userID int64, islandID int64, fragmentIDs []int64) (domain.Island, error) {
	return s.repo.RemoveFragments(ctx, userID, islandID, fragmentIDs)
}

func (s *Service) Fragments(ctx context.Context, userID int64, name, rawLimit string) ([]domain.FragmentPreview, error) {
	return s.repo.Fragments(ctx, userID, name, parseLimit(rawLimit, 50))
}

func (s *Service) FragmentsByID(ctx context.Context, userID int64, islandID int64, rawLimit string) ([]domain.FragmentPreview, error) {
	return s.repo.FragmentsByID(ctx, userID, islandID, parseLimit(rawLimit, 50))
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
