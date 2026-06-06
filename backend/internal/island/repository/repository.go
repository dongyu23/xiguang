package repository

import (
	"context"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/island/domain"
)

type Repository interface {
	List(ctx context.Context, userID int64) ([]domain.Island, error)
	UpsertManual(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Island, error)
	Find(ctx context.Context, userID int64, idOrName string) (domain.Island, error)
	Delete(ctx context.Context, userID, id int64) (bool, error)
	Fragments(ctx context.Context, userID int64, name string, limit int) ([]domain.FragmentPreview, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) List(ctx context.Context, userID int64) ([]domain.Island, error) {
	rows, err := r.db.Query(ctx, `SELECT name, status::text, fragment_count, COALESCE(description,''), updated_at
		FROM islands WHERE user_id=$1 AND deleted_at IS NULL ORDER BY fragment_count DESC, updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.Island{}
	for rows.Next() {
		var item domain.Island
		if err := rows.Scan(&item.Name, &item.Status, &item.FragmentCount, &item.Description, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) UpsertManual(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Island, error) {
	var dto domain.Island
	if params.ID > 0 {
		err := r.db.QueryRow(ctx, `UPDATE islands SET name=$3, description=$4, updated_at=now()
			WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL
			RETURNING id::text, name, status::text, fragment_count, COALESCE(description,''), updated_at`,
			userID, params.ID, params.Name, params.Description).
			Scan(&dto.ID, &dto.Name, &dto.Status, &dto.FragmentCount, &dto.Description, &dto.UpdatedAt)
		return dto, err
	}
	err := r.db.QueryRow(ctx, `INSERT INTO islands(user_id, name, description, status, fragment_count)
		VALUES($1,$2,$3,'star_point',0)
		RETURNING id::text, name, status::text, fragment_count, COALESCE(description,''), updated_at`,
		userID, params.Name, params.Description).
		Scan(&dto.ID, &dto.Name, &dto.Status, &dto.FragmentCount, &dto.Description, &dto.UpdatedAt)
	return dto, err
}

func (r *PG) Find(ctx context.Context, userID int64, idOrName string) (domain.Island, error) {
	var dto domain.Island
	id, err := strconv.ParseInt(idOrName, 10, 64)
	if err == nil {
		err = r.db.QueryRow(ctx, `SELECT id::text, name, status::text, fragment_count, COALESCE(description,''), updated_at
			FROM islands WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, id).
			Scan(&dto.ID, &dto.Name, &dto.Status, &dto.FragmentCount, &dto.Description, &dto.UpdatedAt)
		return dto, err
	}
	err = r.db.QueryRow(ctx, `SELECT id::text, name, status::text, fragment_count, COALESCE(description,''), updated_at
		FROM islands WHERE user_id=$1 AND name=$2 AND deleted_at IS NULL`, userID, idOrName).
		Scan(&dto.ID, &dto.Name, &dto.Status, &dto.FragmentCount, &dto.Description, &dto.UpdatedAt)
	return dto, err
}

func (r *PG) Delete(ctx context.Context, userID, id int64) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE islands SET deleted_at=now(), updated_at=now() WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, id)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

func (r *PG) Fragments(ctx context.Context, userID int64, name string, limit int) ([]domain.FragmentPreview, error) {
	rows, err := r.db.Query(ctx, `SELECT f.id, f.public_id::text, f.content_text, COALESCE(f.emotion,'说不清'), f.created_at, f.updated_at
		FROM fragments f
		JOIN fragment_tags ft ON ft.fragment_id=f.id
		JOIN tags t ON t.id=ft.tag_id AND t.deleted_at IS NULL
		WHERE f.user_id=$1 AND f.is_deleted=FALSE AND t.name=$2
		ORDER BY f.created_at DESC LIMIT $3`, userID, name, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.FragmentPreview{}
	for rows.Next() {
		var item domain.FragmentPreview
		if err := rows.Scan(&item.ID, &item.PublicID, &item.ContentText, &item.Emotion, &item.CreatedAt, &item.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
