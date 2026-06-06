package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/ai/domain"
)

type Repository interface {
	LogGlowSummary(ctx context.Context, userID int64, req domain.GlowSummaryRequest, response string) error
	ListRequests(ctx context.Context, userID int64) ([]domain.RequestLog, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) LogGlowSummary(ctx context.Context, userID int64, req domain.GlowSummaryRequest, response string) error {
	_, err := r.db.Exec(ctx, `INSERT INTO ai_requests(user_id, mode, fragment_ids, status, response)
		VALUES($1,$2,$3,'not_implemented',$4::jsonb)`, userID, req.Mode, req.FragmentIDs, response)
	return err
}

func (r *PG) ListRequests(ctx context.Context, userID int64) ([]domain.RequestLog, error) {
	rows, err := r.db.Query(ctx, `SELECT id, mode, status, response::text, created_at
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
