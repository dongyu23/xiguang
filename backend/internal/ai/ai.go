package ai

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

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

func New(db *pgxpool.Pool, cfg config.Config, quotas ...service.QuotaService) *Handler {
	reader := &pgSourceReader{db: db}
	return handler.New(service.New(repository.NewPG(db), provider.NewDeepSeek(cfg), reader, quotas...))
}

type pgSourceReader struct{ db *pgxpool.Pool }

func (r *pgSourceReader) AIEnabled(ctx context.Context, userID int64) (bool, error) {
	var enabled bool
	err := r.db.QueryRow(ctx, `SELECT ai_enabled AND ai_consent_accepted_at IS NOT NULL
		FROM users WHERE id=$1 AND deleted_at IS NULL`, userID).Scan(&enabled)
	return enabled, err
}

func (r *pgSourceReader) ResolveScope(ctx context.Context, userID int64, scope domain.AIScope) ([]service.FragmentSummary, error) {
	query := `SELECT f.id,f.content_text,COALESCE(f.emotion,'说不清'),f.created_at,
		COALESCE(jsonb_agg(DISTINCT t.name) FILTER(WHERE t.name IS NOT NULL),'[]'::jsonb)
		FROM fragments f
		LEFT JOIN fragment_tags ft ON ft.fragment_id=f.id
		LEFT JOIN tags t ON t.id=ft.tag_id AND t.deleted_at IS NULL`
	args := []any{userID}
	switch scope.Type {
	case "fragments":
		query += ` WHERE f.user_id=$1 AND f.is_deleted=FALSE AND f.id=ANY($2)`
		args = append(args, scope.FragmentIDs)
	case "island":
		query += ` JOIN island_fragments igf ON igf.fragment_id=f.id
			JOIN islands i ON i.id=igf.island_id AND i.user_id=$1 AND i.deleted_at IS NULL
			WHERE f.user_id=$1 AND f.is_deleted=FALSE AND i.id=$2`
		args = append(args, scope.IslandID)
	case "range":
		query += ` WHERE f.user_id=$1 AND f.is_deleted=FALSE AND f.created_at>now()-($2*interval '1 day')`
		args = append(args, scope.RangeDays)
	default:
		return nil, errors.New("invalid_scope")
	}
	query += ` GROUP BY f.id ORDER BY f.created_at DESC LIMIT 500`
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []service.FragmentSummary{}
	for rows.Next() {
		var item service.FragmentSummary
		var tags []byte
		if err := rows.Scan(&item.ID, &item.ContentText, &item.Emotion, &item.CreatedAt, &tags); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(tags, &item.Tags)
		items = append(items, item)
	}
	if scope.Type == "fragments" && len(items) != len(scope.FragmentIDs) {
		return nil, errors.New("fragment_scope_mismatch")
	}
	return items, rows.Err()
}

func (r *pgSourceReader) IslandCandidates(ctx context.Context, userID int64) ([]service.IslandCandidate, error) {
	rows, err := r.db.Query(ctx, `SELECT i.id,i.name,COALESCE(i.description,''),i.updated_at,
		COALESCE(array_agg(DISTINCT f.id) FILTER(WHERE f.id IS NOT NULL),'{}'),
		COALESCE(array_agg(DISTINCT f.emotion) FILTER(WHERE f.emotion IS NOT NULL),'{}'),
		COALESCE(array_agg(DISTINCT t.name) FILTER(WHERE t.name IS NOT NULL),'{}')
		FROM islands i
		LEFT JOIN island_fragments igf ON igf.island_id=i.id
		LEFT JOIN fragments f ON f.id=igf.fragment_id AND f.is_deleted=FALSE
		LEFT JOIN fragment_tags ft ON ft.fragment_id=f.id
		LEFT JOIN tags t ON t.id=ft.tag_id AND t.deleted_at IS NULL
		WHERE i.user_id=$1 AND i.deleted_at IS NULL
		GROUP BY i.id ORDER BY i.updated_at DESC LIMIT 40`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	all := []service.IslandCandidate{}
	for rows.Next() {
		var c service.IslandCandidate
		if err := rows.Scan(&c.ID, &c.Name, &c.Description, &c.UpdatedAt, &c.FragmentIDs, &c.Emotions, &c.Tags); err != nil {
			return nil, err
		}
		all = append(all, c)
	}
	keep := map[int]bool{}
	for i := 0; i < len(all); i++ {
		for j := i + 1; j < len(all); j++ {
			score := overlapScore(all[i].FragmentIDs, all[j].FragmentIDs)*4 + overlapScore(all[i].Tags, all[j].Tags)*3 + overlapScore(all[i].Emotions, all[j].Emotions)
			if durationAbs(all[i].UpdatedAt.Sub(all[j].UpdatedAt)) <= 14*24*time.Hour {
				score++
			}
			if score >= 2 {
				keep[i] = true
				keep[j] = true
				all[i].Score += score
				all[j].Score += score
			}
		}
	}
	out := []service.IslandCandidate{}
	for i, c := range all {
		if keep[i] {
			out = append(out, c)
		}
	}
	return out, rows.Err()
}

func overlapScore[T comparable](a, b []T) int {
	set := map[T]bool{}
	for _, v := range a {
		set[v] = true
	}
	n := 0
	for _, v := range b {
		if set[v] {
			n++
		}
	}
	return n
}
func durationAbs(v time.Duration) time.Duration {
	if v < 0 {
		return -v
	}
	return v
}

var _ http.Handler = (*Handler)(nil)
