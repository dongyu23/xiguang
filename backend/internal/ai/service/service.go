package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/provider"
	"xiguang/backend/internal/ai/repository"
)

const defaultMode = "dont_explain_me"

type FragmentSummary struct {
	ID          int64    `json:"id"`
	ContentText string   `json:"content_text"`
	Emotion     string   `json:"emotion"`
	Tags        []string `json:"tags"`
}

type FragmentLister interface {
	ListAllFragments(ctx context.Context, userID int64) ([]FragmentSummary, error)
}

type Service struct {
	repo repository.Repository
	ai   provider.Provider
	frag FragmentLister
}

func New(repo repository.Repository, aiProvider provider.Provider, frag FragmentLister) *Service {
	return &Service{repo: repo, ai: aiProvider, frag: frag}
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
	_ = s.repo.LogGlowSummary(ctx, userID, req, `{"message":"MVP 预留"}`)
	return response
}

func (s *Service) Requests(ctx context.Context, userID int64) (map[string]any, error) {
	items, err := s.repo.ListRequests(ctx, userID)
	if err != nil {
		return nil, err
	}
	return map[string]any{"requests": items, "generated_at": time.Now()}, nil
}

func (s *Service) BuildIslands(ctx context.Context, userID int64) domain.BuildIslandsResponse {
	dailyCount, err := s.repo.DailyBuildCount(ctx, userID)
	if err != nil {
		dailyCount = 0
	}
	if dailyCount >= repository.MaxDailyBuilds {
		return domain.BuildIslandsResponse{
			Status:  "rate_limited",
			Message: fmt.Sprintf("今天已经帮你整理过 %d 次啦。明天再来看吧。", dailyCount),
		}
	}

	fragments, err := s.frag.ListAllFragments(ctx, userID)
	if err != nil {
		return domain.BuildIslandsResponse{
			Status:  "error",
			Message: "暂时无法读取你的光片。请稍后再试。",
		}
	}

	if len(fragments) < 3 {
		return domain.BuildIslandsResponse{
			Status:  "not_enough",
			Message: "光还不够多，再捕一些光吧。",
		}
	}

	fragJSON, _ := json.Marshal(fragments)
	inputSummary := fmt.Sprintf("analysing %d fragments", len(fragments))

	aiResponse, tokens, err := s.ai.Chat(ctx, buildIslandsSystemPrompt, string(fragJSON))
	if err != nil {
		_ = s.repo.LogBuildIslands(ctx, userID, inputSummary, fmt.Sprintf(`{"error":"%s"}`, err.Error()))
		return domain.BuildIslandsResponse{
			Status:  "error",
			Message: "星图管理员暂时无法工作。请稍后再试。",
		}
	}

	_ = s.repo.LogBuildIslands(ctx, userID, inputSummary, aiResponse)

	var parsed struct {
		Islands []domain.AISuggestedIsland `json:"islands"`
	}
	if err := json.Unmarshal([]byte(aiResponse), &parsed); err != nil {
		return domain.BuildIslandsResponse{
			Status:  "parse_error",
			Message: "星图管理员看懂了，但没能说清楚。要不要再试一次？",
		}
	}

	_ = tokens
	return domain.BuildIslandsResponse{
		Status:  "success",
		Message: fmt.Sprintf("从 %d 束光里，发现了一些隐秘的联系。", len(fragments)),
		Islands: parsed.Islands,
	}
}

const buildIslandsSystemPrompt = `你是隙光 App 的星图管理员。用户记录了许多"光片"——包含文字内容、情绪和标签的碎片记录。

你的任务：分析用户的所有光片，发现它们之间隐秘的联系。将属于同一主题、情绪脉络或内在关联的光片分组为"小岛"。

规则：
- 每组建议一个岛名：温柔、诗意的中文名，2-6个字，像一首小诗的题目
- 每组一段简短描述（10-30字）：为什么这些光片属于一起，用温柔、克制的语气
- 一束光片可以属于多个岛
- 只返回有意义的分组（每组至少2束光片），不要强行分组
- 最多返回5组
- 不要评价用户，不要用"你应该""这表明"，用"似乎""好像""要不要"
- 如果光片之间关联不明显，可以说"这些光各自散落着，暂时没有明显的星座。"

严格按以下 JSON 格式返回，不要加任何其他文本：
{
  "islands": [
    {
      "name": "岛名",
      "description": "简短描述",
      "fragment_ids": [1, 5, 12],
      "confidence": "high"
    }
  ]
}`
