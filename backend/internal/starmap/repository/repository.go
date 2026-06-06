package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/starmap/domain"
)

type Repository interface {
	Fragments(ctx context.Context, userID int64, limit int) ([]domain.FragmentSource, error)
	Relations(ctx context.Context, userID int64, limit int) ([]domain.RelationSource, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) Fragments(ctx context.Context, userID int64, limit int) ([]domain.FragmentSource, error) {
	rows, err := r.db.Query(ctx, `SELECT id, content_text, emotion
		FROM fragments WHERE user_id=$1 AND is_deleted=FALSE
		ORDER BY created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.FragmentSource{}
	for rows.Next() {
		var item domain.FragmentSource
		if err := rows.Scan(&item.ID, &item.Text, &item.Emotion); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) Relations(ctx context.Context, userID int64, limit int) ([]domain.RelationSource, error) {
	rows, err := r.db.Query(ctx, `SELECT source_fragment_id, target_fragment_id, relation_type
		FROM relations WHERE user_id=$1 LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.RelationSource{}
	for rows.Next() {
		var item domain.RelationSource
		if err := rows.Scan(&item.SourceFragmentID, &item.TargetFragmentID, &item.RelationType); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
