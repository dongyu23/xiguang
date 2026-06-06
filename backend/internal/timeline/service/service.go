package service

import (
	"context"
	"strconv"
	"time"

	"xiguang/backend/internal/timeline/domain"
	"xiguang/backend/internal/timeline/repository"
)

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) Timeline(ctx context.Context, userID int64, emotion, tag, rawLimit string) (domain.Response, error) {
	items, err := s.repo.List(ctx, userID, domain.Query{Emotion: emotion, Tag: tag, Limit: parseLimit(rawLimit, 100)})
	if err != nil {
		return domain.Response{}, err
	}
	groups := make([]domain.DateGroup, 0)
	index := map[string]int{}
	now := time.Now()
	for _, item := range items {
		label := dateLabel(now, item.CreatedAt)
		if _, ok := index[label]; !ok {
			index[label] = len(groups)
			groups = append(groups, domain.DateGroup{Label: label})
		}
		i := index[label]
		groups[i].Fragments = append(groups[i].Fragments, item)
		groups[i].Count++
	}
	return domain.Response{Groups: groups, Items: items, HasMore: false}, nil
}

func dateLabel(now, value time.Time) string {
	vy, vm, vd := value.In(now.Location()).Date()
	day := time.Date(vy, vm, vd, 0, 0, 0, 0, now.Location())
	return day.Format("2006-01-02")
}

func parseLimit(raw string, fallback int) int {
	if raw == "" {
		return fallback
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 || n > 200 {
		return fallback
	}
	return n
}
