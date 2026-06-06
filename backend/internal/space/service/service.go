package service

import "xiguang/backend/internal/space/domain"

type Service struct{}

func New() *Service {
	return &Service{}
}

func (s *Service) Config() domain.Config {
	return domain.Config{
		Theme:             domain.ThemeStarry,
		BreathingMotion:   true,
		WhiteNoiseEnabled: false,
	}
}

func (s *Service) UpdateConfig() domain.Config {
	return s.Config()
}
