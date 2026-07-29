package service

import (
	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/whitenoise/domain"
)

type Service struct{}

func New() *Service {
	return &Service{}
}

func (s *Service) List(tier string) []domain.NoiseAudio {
	items := make([]domain.NoiseAudio, len(domain.StaticList))
	copy(items, domain.StaticList)
	for i := range items {
		items[i].Locked = !billingdomain.TierAllows(tier, items[i].RequiredTier)
	}
	return items
}
