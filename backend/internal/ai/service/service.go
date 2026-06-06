package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
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

	if len(fragments) < 2 {
		return domain.BuildIslandsResponse{
			Status:  "not_enough",
			Message: "还需要至少两束光，才能试着发现一座小岛。",
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
	if len(parsed.Islands) == 0 {
		return domain.BuildIslandsResponse{
			Status:  "success",
			Message: "这些光各自散落着，暂时没有明显的小岛。",
			Islands: []domain.AISuggestedIsland{},
		}
	}

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

func (s *Service) PolishFragment(ctx context.Context, userID int64, req domain.PolishRequest) domain.PolishResponse {
	if req.ContentText == "" {
		return domain.PolishResponse{
			Status:  "empty",
			Message: "这束光还没有内容，不需要润色。",
		}
	}
	if len([]rune(req.ContentText)) < 4 {
		return domain.PolishResponse{
			Status:  "too_short",
			Message: "它已经很简短了，或许不需要润色。",
		}
	}

	userMsg := fmt.Sprintf("原文：%s\n情绪：%s\n\n请润色这段文字，保持原意和长度，让它更温柔、更有画面感。只返回润色后的文字，不要加引号或说明。",
		req.ContentText, req.Emotion)

	polished, _, err := s.ai.TextChat(ctx, polishSystemPrompt, userMsg)
	if err != nil {
		return domain.PolishResponse{
			Status:  "error",
			Message: "星图管理员一时失神，请稍后再试。",
		}
	}

	polished = strings.TrimSpace(polished)
	if polished == "" || polished == req.ContentText {
		return domain.PolishResponse{
			Status:       "no_change",
			Message:      "它已经足够好了，不需要改动。",
			PolishedText: req.ContentText,
		}
	}

	return domain.PolishResponse{
		Status:       "success",
		Message:      "润色完成。",
		PolishedText: polished,
	}
}

const polishSystemPrompt = "你是隙光 App 的星图管理员，负责轻轻帮用户润色文字。\n\n规则：\n- 保持原文的语气、长度和核心意思\n- 让文字更温柔、更有画面感，但不刻意堆砌修辞\n- 不改动用户原本想表达的情绪\n- 不改动任何人名、地名、具体时间\n- 如果原文已经很好，就原样返回\n- 只返回润色后的文字，不要加引号、不要加任何说明"
