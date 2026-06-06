package service

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	"xiguang/backend/internal/fragment/domain"
	"xiguang/backend/internal/fragment/repository"
)

var ErrEmptyLight = errors.New("empty_light")

type WeaveFunc func(ctx context.Context, userID, sourceFragmentID, targetFragmentID int64, relationType, note string) (any, error)

type Service struct {
	repo  repository.Repository
	weave WeaveFunc
}

func New(repo repository.Repository, weave WeaveFunc) *Service {
	return &Service{repo: repo, weave: weave}
}

func (s *Service) Create(ctx context.Context, userID int64, params domain.CreateParams) (domain.Fragment, error) {
	params.ContentText = strings.TrimSpace(params.ContentText)
	if params.ContentText == "" && len(params.MediaURLs) == 0 {
		return domain.Fragment{}, ErrEmptyLight
	}
	if params.Emotion == "" {
		params.Emotion = "说不清"
	}
	tags := cleanTags(params.Tags)
	media := cleanTags(params.MediaURLs)
	dto, err := s.repo.Create(ctx, userID, params.ContentText, params.Emotion, statusFor(params.Emotion, len(tags), len(media)), tags, media)
	if err != nil {
		return domain.Fragment{}, err
	}
	if params.ClientOpID != "" {
		_ = s.repo.LogCreate(ctx, userID, params.ClientOpID, dto)
	}
	return dto, nil
}

func (s *Service) List(ctx context.Context, userID int64, emotion, tag, rawLimit string) ([]domain.Fragment, error) {
	return s.repo.List(ctx, userID, domain.ListQuery{Emotion: emotion, Tag: tag, Limit: parseLimit(rawLimit, 50)})
}

func (s *Service) Timeline(ctx context.Context, userID int64, emotion, tag, rawLimit string) (domain.TimelineResponse, error) {
	items, err := s.repo.List(ctx, userID, domain.ListQuery{Emotion: emotion, Tag: tag, Limit: parseLimit(rawLimit, 100)})
	if err != nil {
		return domain.TimelineResponse{}, err
	}
	groups := make([]domain.TimelineGroup, 0)
	index := map[string]int{}
	now := time.Now()
	for _, item := range items {
		label := dateLabel(now, item.CreatedAt)
		if _, ok := index[label]; !ok {
			index[label] = len(groups)
			groups = append(groups, domain.TimelineGroup{Label: label})
		}
		i := index[label]
		groups[i].Fragments = append(groups[i].Fragments, item)
		groups[i].Count++
	}
	return domain.TimelineResponse{Groups: groups, Items: items, HasMore: false}, nil
}

func (s *Service) Get(ctx context.Context, userID, id int64) (domain.Fragment, error) {
	return s.repo.FindByID(ctx, userID, id)
}

func (s *Service) Update(ctx context.Context, userID int64, params domain.UpdateParams) (domain.Fragment, error) {
	params.ContentText = strings.TrimSpace(params.ContentText)
	if params.ContentText == "" {
		return domain.Fragment{}, ErrEmptyLight
	}
	if params.Emotion == "" {
		params.Emotion = "说不清"
	}
	tags := cleanTags(params.Tags)
	return s.repo.Update(ctx, userID, params.ID, params.ContentText, params.Emotion, statusFor(params.Emotion, len(tags), 0), tags)
}

func (s *Service) Delete(ctx context.Context, userID, id int64) (bool, error) {
	return s.repo.Delete(ctx, userID, id)
}

func (s *Service) Weave(ctx context.Context, userID, sourceID, targetID int64, relationType, note string) (any, error) {
	return s.weave(ctx, userID, sourceID, targetID, relationType, note)
}

func cleanTags(tags []string) []string {
	seen := map[string]bool{}
	result := make([]string, 0, len(tags))
	for _, tag := range tags {
		tag = strings.TrimSpace(strings.TrimPrefix(tag, "#"))
		if tag == "" || seen[tag] {
			continue
		}
		seen[tag] = true
		result = append(result, tag)
	}
	return result
}

func statusFor(emotion string, tags, media int) string {
	switch {
	case tags >= 3:
		return "island_core"
	case media > 0:
		return "stardust"
	case emotion == "被击中" || emotion == "开心":
		return "seed"
	case emotion == "疲惫" || emotion == "焦虑":
		return "tide"
	default:
		return "twilight"
	}
}

func dateLabel(now, value time.Time) string {
	ny, nm, nd := now.Date()
	vy, vm, vd := value.In(now.Location()).Date()
	today := time.Date(ny, nm, nd, 0, 0, 0, 0, now.Location())
	day := time.Date(vy, vm, vd, 0, 0, 0, 0, now.Location())
	switch today.Sub(day).Hours() / 24 {
	case 0:
		return "今天"
	case 1:
		return "昨天"
	default:
		return day.Format("2006-01-02")
	}
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
