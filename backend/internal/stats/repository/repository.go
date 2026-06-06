package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/stats/domain"
)

type Repository interface {
	EmotionCounts(ctx context.Context, userID int64) ([]domain.EmotionCount, error)
	FreqWords(ctx context.Context, userID int64, limit int) ([]domain.FreqWord, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) EmotionCounts(ctx context.Context, userID int64) ([]domain.EmotionCount, error) {
	rows, err := r.db.Query(ctx, `SELECT emotion, COUNT(*) FROM fragments
		WHERE user_id=$1 AND is_deleted=FALSE AND created_at > now() - interval '7 days'
		GROUP BY emotion ORDER BY COUNT(*) DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.EmotionCount{}
	for rows.Next() {
		var item domain.EmotionCount
		if err := rows.Scan(&item.Name, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) FreqWords(ctx context.Context, userID int64, limit int) ([]domain.FreqWord, error) {
	rows, err := r.db.Query(ctx, `SELECT name, use_count FROM tags
		WHERE user_id=$1 ORDER BY use_count DESC, updated_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.FreqWord{}
	for rows.Next() {
		var item domain.FreqWord
		if err := rows.Scan(&item.Text, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
