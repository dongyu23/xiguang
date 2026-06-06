package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai/domain"
)

type Repository interface {
	LogGlowSummary(ctx context.Context, userID int64, req domain.GlowSummaryRequest, response string) error
	LogBuildIslands(ctx context.Context, userID int64, input, response string) error
	ListRequests(ctx context.Context, userID int64) ([]domain.RequestLog, error)
	DailyBuildCount(ctx context.Context, userID int64) (int, error)
}

const MaxDailyBuilds = 3

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) LogGlowSummary(ctx context.Context, userID int64, req domain.GlowSummaryRequest, response string) error {
	_, err := r.db.Exec(ctx, `INSERT INTO ai_requests(user_id, mode, fragment_ids, status, input_prompt, output_raw)
		VALUES($1,$2,$3,'completed',$4,$5)`, userID, req.Mode, req.FragmentIDs, req.Context, response)
	return err
}

func (r *PG) LogBuildIslands(ctx context.Context, userID int64, input, output string) error {
	_, err := r.db.Exec(ctx, `INSERT INTO ai_requests(user_id, mode, fragment_ids, status, input_prompt, output_raw)
		VALUES($1,'build_islands','{}','completed',$2,$3)`, userID, input, output)
	return err
}

func (r *PG) ListRequests(ctx context.Context, userID int64) ([]domain.RequestLog, error) {
	rows, err := r.db.Query(ctx, `SELECT id, mode, status, COALESCE(output_raw,'')::text, created_at
		FROM ai_requests WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.RequestLog{}
	for rows.Next() {
		var item domain.RequestLog
		if err := rows.Scan(&item.ID, &item.Mode, &item.Status, &item.Response, &item.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) DailyBuildCount(ctx context.Context, userID int64) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM ai_requests
		WHERE user_id=$1 AND mode='build_islands' AND created_at > now() - INTERVAL '1 day'`,
		userID).Scan(&count)
	return count, err
}
