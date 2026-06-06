package service

import "xiguang/backend/internal/whitenoise/domain"

type Service struct{}

func New() *Service {
	return &Service{}
}

func (s *Service) List() []domain.NoiseAudio {
	items := make([]domain.NoiseAudio, len(domain.StaticList))
	copy(items, domain.StaticList)
	return items
}
