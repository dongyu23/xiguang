package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/tag/domain"
)

type Repository interface {
	List(ctx context.Context, userID int64, pageSize int) ([]domain.Tag, error)
	Create(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Tag, error)
	Update(ctx context.Context, userID, tagID int64, params domain.UpsertParams) (domain.Tag, error)
	Delete(ctx context.Context, userID, tagID int64) (bool, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) List(ctx context.Context, userID int64, pageSize int) ([]domain.Tag, error) {
	rows, err := r.db.Query(ctx, `SELECT id, public_id::text, name, COALESCE(color,''), use_count, created_at, updated_at
		FROM tags WHERE user_id=$1 AND deleted_at IS NULL ORDER BY use_count DESC, updated_at DESC LIMIT $2`, userID, pageSize)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.Tag{}
	for rows.Next() {
		var item domain.Tag
		if err := rows.Scan(&item.ID, &item.PublicID, &item.Name, &item.Color, &item.UseCount, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) Create(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Tag, error) {
	var dto domain.Tag
	err := r.db.QueryRow(ctx, `INSERT INTO tags(user_id,name,color) VALUES($1,$2,NULLIF($3,''))
		ON CONFLICT(user_id,name) WHERE deleted_at IS NULL DO UPDATE SET color=COALESCE(NULLIF(EXCLUDED.color,''), tags.color), updated_at=now()
		RETURNING id, public_id::text, name, COALESCE(color,''), use_count, created_at, updated_at`, userID, params.Name, params.Color).
		Scan(&dto.ID, &dto.PublicID, &dto.Name, &dto.Color, &dto.UseCount, &dto.CreatedAt, &dto.UpdatedAt)
	return dto, err
}

func (r *PG) Update(ctx context.Context, userID, tagID int64, params domain.UpsertParams) (domain.Tag, error) {
	var dto domain.Tag
	err := r.db.QueryRow(ctx, `UPDATE tags SET name=$3, color=NULLIF($4,''), updated_at=now()
		WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL
		RETURNING id, public_id::text, name, COALESCE(color,''), use_count, created_at, updated_at`, userID, tagID, params.Name, params.Color).
		Scan(&dto.ID, &dto.PublicID, &dto.Name, &dto.Color, &dto.UseCount, &dto.CreatedAt, &dto.UpdatedAt)
	return dto, err
}

func (r *PG) Delete(ctx context.Context, userID, tagID int64) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE tags SET deleted_at=now(), updated_at=now() WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, tagID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}
