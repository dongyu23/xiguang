package service

import (
	"context"
	"errors"

	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/space/domain"
	"xiguang/backend/internal/space/repository"
)

var (
	ErrThemeNotFound     = errors.New("space_theme_not_found")
	ErrEntitlementNeeded = errors.New("entitlement_required")
)

type EntitlementService interface {
	Entitlement(context.Context, int64) (billingdomain.Entitlement, error)
}

type Service struct {
	repo         repository.Repository
	entitlements EntitlementService
}

func New(repo repository.Repository, entitlements EntitlementService) *Service {
	return &Service{repo: repo, entitlements: entitlements}
}

func (s *Service) Config(ctx context.Context, userID int64) (domain.Config, error) {
	return s.repo.Config(ctx, userID)
}

func (s *Service) Themes(ctx context.Context, userID int64) ([]domain.Theme, error) {
	config, err := s.repo.Config(ctx, userID)
	if err != nil {
		return nil, err
	}
	tier := "glimmer"
	if s.entitlements != nil {
		entitlement, entitlementErr := s.entitlements.Entitlement(ctx, userID)
		if entitlementErr != nil {
			return nil, entitlementErr
		}
		tier = entitlement.Tier
	}
	items := make([]domain.Theme, len(domain.Themes))
	copy(items, domain.Themes)
	for index := range items {
		items[index].Locked = !billingdomain.TierAllows(tier, items[index].RequiredTier)
		items[index].Selected = items[index].ID == config.Theme
	}
	return items, nil
}

func (s *Service) CurrentTheme(ctx context.Context, userID int64) (domain.Theme, error) {
	items, err := s.Themes(ctx, userID)
	if err != nil {
		return domain.Theme{}, err
	}
	for _, item := range items {
		if item.Selected {
			return item, nil
		}
	}
	return items[0], nil
}

func (s *Service) UpdateConfig(ctx context.Context, userID int64, config domain.Config) (domain.Config, error) {
	var selected *domain.Theme
	for index := range domain.Themes {
		if domain.Themes[index].ID == config.Theme {
			selected = &domain.Themes[index]
			break
		}
	}
	if selected == nil {
		return domain.Config{}, ErrThemeNotFound
	}
	tier := "glimmer"
	if s.entitlements != nil {
		entitlement, err := s.entitlements.Entitlement(ctx, userID)
		if err != nil {
			return domain.Config{}, err
		}
		tier = entitlement.Tier
	}
	if !billingdomain.TierAllows(tier, selected.RequiredTier) || (config.WhiteNoiseEnabled && tier == "glimmer") {
		return domain.Config{}, ErrEntitlementNeeded
	}
	return s.repo.Update(ctx, userID, config)
}
