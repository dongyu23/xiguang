package repository

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/relation/domain"
)

type Repository interface {
	Create(ctx context.Context, userID int64, params domain.CreateParams) (domain.Relation, error)
	List(ctx context.Context, userID, fragmentID int64) ([]domain.Relation, error)
	Delete(ctx context.Context, userID, relationID int64) (bool, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) Create(ctx context.Context, userID int64, params domain.CreateParams) (domain.Relation, error) {
	var dto domain.Relation
	err := r.db.QueryRow(ctx, `WITH owned AS (
			SELECT COUNT(*) AS count FROM fragments
			WHERE user_id=$1 AND is_deleted=FALSE AND id IN ($2,$3)
		)
		INSERT INTO relations(user_id, source_fragment_id, target_fragment_id, relation_type, note)
		SELECT $1,$2,$3,$4,$5 FROM owned WHERE count=2
		ON CONFLICT(user_id, source_fragment_id, target_fragment_id, relation_type) DO UPDATE SET note=EXCLUDED.note
		RETURNING id, public_id::text, user_id, source_fragment_id, target_fragment_id, relation_type, COALESCE(note,''), created_at`,
		userID, params.SourceFragmentID, params.TargetFragmentID, strings.TrimSpace(params.RelationType), params.Note).
		Scan(&dto.ID, &dto.PublicID, &dto.UserID, &dto.SourceFragmentID, &dto.TargetFragmentID, &dto.RelationType, &dto.Note, &dto.CreatedAt)
	return dto, err
}

func (r *PG) List(ctx context.Context, userID, fragmentID int64) ([]domain.Relation, error) {
	rows, err := r.db.Query(ctx, `SELECT id, public_id::text, user_id, source_fragment_id, target_fragment_id, relation_type, COALESCE(note,''), created_at
		FROM relations WHERE user_id=$1 AND deleted_at IS NULL AND ($2::bigint=0 OR source_fragment_id=$2 OR target_fragment_id=$2)
		ORDER BY created_at DESC LIMIT 100`, userID, fragmentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.Relation{}
	for rows.Next() {
		var dto domain.Relation
		if err := rows.Scan(&dto.ID, &dto.PublicID, &dto.UserID, &dto.SourceFragmentID, &dto.TargetFragmentID, &dto.RelationType, &dto.Note, &dto.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, dto)
	}
	return items, rows.Err()
}

func (r *PG) Delete(ctx context.Context, userID, relationID int64) (bool, error) {
	tag, err := r.db.Exec(ctx, `UPDATE relations SET deleted_at=now() WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, relationID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
