package service

import (
	"context"
	"time"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/repository"
)

const defaultMode = "dont_explain_me"

type Service struct {
	repo repository.Repository
}

func New(repo repository.Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) GlowSummary(ctx context.Context, userID int64, req domain.GlowSummaryRequest) domain.GlowSummaryResponse {
	if req.Mode == "" {
		req.Mode = defaultMode
	}
	response := domain.GlowSummaryResponse{
		Status:        "not_implemented",
		Message:       "柔光整理已预留。现在你也可以什么都不解释，只把它放在这里。",
		Keywords:      []string{},
		SuggestionIDs: []int64{},
	}
	_ = s.repo.LogGlowSummary(ctx, userID, req, `{"message":"MVP 预留：柔光整理需要用户主动触发，当前不会后台解释你。"}`)
	return response
}

func (s *Service) Requests(ctx context.Context, userID int64) (map[string]any, error) {
	items, err := s.repo.ListRequests(ctx, userID)
	if err != nil {
		return nil, err
	}
	return map[string]any{"requests": items, "generated_at": time.Now()}, nil
}
