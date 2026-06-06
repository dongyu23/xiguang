package service

import "xiguang/backend/internal/emotion/domain"

type Service struct{}

func New() *Service {
	return &Service{}
}

func (s *Service) List() []domain.Emotion {
	items := make([]domain.Emotion, len(domain.StaticList))
	copy(items, domain.StaticList)
	return items
}
