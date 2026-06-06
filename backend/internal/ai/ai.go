package ai

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai/domain"
	"xiguang/backend/internal/ai/handler"
	"xiguang/backend/internal/ai/provider"
	"xiguang/backend/internal/ai/repository"
	"xiguang/backend/internal/ai/service"
	"xiguang/backend/internal/infra/config"
)

type Handler = handler.Handler
type GlowSummaryRequest = domain.GlowSummaryRequest
type GlowSummaryResponse = domain.GlowSummaryResponse

func New(db *pgxpool.Pool, cfg config.Config) *Handler {
	aiProvider := provider.NewDeepSeek(cfg)
	fragLister := &pgFragmentLister{db: db}
	return handler.New(service.New(repository.NewPG(db), aiProvider, fragLister))
}

type pgFragmentLister struct {
	db *pgxpool.Pool
}

func (l *pgFragmentLister) ListAllFragments(ctx context.Context, userID int64) ([]service.FragmentSummary, error) {
	rows, err := l.db.Query(ctx, `SELECT f.id, f.content_text, COALESCE(f.emotion, '说不清'),
		COALESCE(jsonb_agg(DISTINCT t.name) FILTER (WHERE t.name IS NOT NULL), '[]'::jsonb)
		FROM fragments f
		LEFT JOIN fragment_tags ft ON ft.fragment_id = f.id
		LEFT JOIN tags t ON t.id = ft.tag_id AND t.deleted_at IS NULL
		WHERE f.user_id = $1 AND f.is_deleted = FALSE
		GROUP BY f.id
		ORDER BY f.created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []service.FragmentSummary
	for rows.Next() {
		var item service.FragmentSummary
		var tagsJSON []byte
		if err := rows.Scan(&item.ID, &item.ContentText, &item.Emotion, &tagsJSON); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(tagsJSON, &item.Tags)
		if item.Tags == nil {
			item.Tags = []string{}
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

var _ http.Handler = (*Handler)(nil)
