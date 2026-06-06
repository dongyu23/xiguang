package service

import (
	"context"
	"sort"
	"time"

	"xiguang/backend/internal/stats/domain"
	"xiguang/backend/internal/stats/repository"
)

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) EmotionDensity(ctx context.Context, userID int64) (domain.EmotionDensity, error) {
	items, err := s.repo.EmotionCounts(ctx, userID)
	if err != nil {
		return domain.EmotionDensity{}, err
	}
	total := 0
	for _, item := range items {
		total += item.Count
	}
	return domain.EmotionDensity{
		Period:      "7d",
		Total:       total,
		Emotions:    items,
		GeneratedAt: time.Now(),
	}, nil
}

func (s *Service) FreqWords(ctx context.Context, userID int64) (domain.FreqWords, error) {
	items, err := s.repo.FreqWords(ctx, userID, 20)
	if err != nil {
		return domain.FreqWords{}, err
	}
	sort.SliceStable(items, func(i, j int) bool { return items[i].Count > items[j].Count })
	return domain.FreqWords{Words: items}, nil
}
