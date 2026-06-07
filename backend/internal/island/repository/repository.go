package repository

import (
	"context"
	"errors"
	"strconv"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/rules"
)

var ErrNotManualIsland = errors.New("island_not_manual")

type Repository interface {
	List(ctx context.Context, userID int64) ([]domain.Island, error)
	UpsertManual(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Island, error)
	Find(ctx context.Context, userID int64, idOrName string) (domain.Island, error)
	Delete(ctx context.Context, userID, id int64) (bool, error)
	AddFragments(ctx context.Context, userID, islandID int64, fragmentIDs []int64) (domain.Island, error)
	RemoveFragments(ctx context.Context, userID, islandID int64, fragmentIDs []int64) (domain.Island, error)
	Fragments(ctx context.Context, userID int64, name string, limit int) ([]domain.FragmentPreview, error)
	FragmentsByID(ctx context.Context, userID, islandID int64, limit int) ([]domain.FragmentPreview, error)
	MarkDormantIslands(ctx context.Context, userID int64) (int, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

const islandSelectCols = `id::text, id, name, status::text, fragment_count, COALESCE(description,''), source_tag_id IS NULL, updated_at`

func scanIsland(row interface{ Scan(...any) error }, dto *domain.Island) error {
	return row.Scan(&dto.ID, &dto.IslandID, &dto.Name, &dto.Status, &dto.FragmentCount, &dto.Description, &dto.Manual, &dto.UpdatedAt)
}

func islandReturning() string {
	return `RETURNING ` + islandSelectCols
}

func (r *PG) List(ctx context.Context, userID int64) ([]domain.Island, error) {
	rows, err := r.db.Query(ctx, `SELECT `+islandSelectCols+`
		FROM islands WHERE user_id=$1 AND deleted_at IS NULL ORDER BY fragment_count DESC, updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.Island{}
	for rows.Next() {
		var item domain.Island
		if err := scanIsland(rows, &item); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) UpsertManual(ctx context.Context, userID int64, params domain.UpsertParams) (domain.Island, error) {
	var dto domain.Island
	if params.ID > 0 {
		err := scanIsland(r.db.QueryRow(ctx, `UPDATE islands SET name=$3, description=$4, updated_at=now()
			WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL
			`+islandReturning(), userID, params.ID, params.Name, params.Description), &dto)
		return dto, err
	}
	err := scanIsland(r.db.QueryRow(ctx, `INSERT INTO islands(user_id, name, description, status, fragment_count)
		VALUES($1,$2,$3,'star_point',0)
		`+islandReturning(), userID, params.Name, params.Description), &dto)
	return dto, err
}

func (r *PG) Find(ctx context.Context, userID int64, idOrName string) (domain.Island, error) {
	var dto domain.Island
	id, err := strconv.ParseInt(idOrName, 10, 64)
	if err == nil {
		err = scanIsland(r.db.QueryRow(ctx, `SELECT `+islandSelectCols+`
			FROM islands WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, id), &dto)
		return dto, err
	}
	err = scanIsland(r.db.QueryRow(ctx, `SELECT `+islandSelectCols+`
		FROM islands WHERE user_id=$1 AND name=$2 AND deleted_at IS NULL`, userID, idOrName), &dto)
	return dto, err
}

func (r *PG) Delete(ctx context.Context, userID, id int64) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE islands SET deleted_at=now(), updated_at=now() WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, id)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

func (r *PG) AddFragments(ctx context.Context, userID, islandID int64, fragmentIDs []int64) (domain.Island, error) {
	if len(fragmentIDs) == 0 {
		return r.Find(ctx, userID, strconv.FormatInt(islandID, 10))
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Island{}, err
	}
	defer tx.Rollback(ctx)

	var sourceTagID *int64
	if err := tx.QueryRow(ctx, `SELECT source_tag_id FROM islands WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`,
		userID, islandID).Scan(&sourceTagID); err != nil {
		return domain.Island{}, err
	}
	if sourceTagID != nil {
		return domain.Island{}, ErrNotManualIsland
	}

	for _, fid := range fragmentIDs {
		if _, err := tx.Exec(ctx, `INSERT INTO island_fragments(island_id, fragment_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
			islandID, fid); err != nil {
			return domain.Island{}, err
		}
	}

	var count int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM island_fragments WHERE island_id=$1`, islandID).Scan(&count); err != nil {
		return domain.Island{}, err
	}
	status := rules.StatusForFragmentCount(count)
	if status == "" {
		status = "star_point"
	}

	var dto domain.Island
	if err := scanIsland(tx.QueryRow(ctx, `UPDATE islands SET fragment_count=$1, status=$2, updated_at=now()
		WHERE user_id=$3 AND id=$4 AND deleted_at IS NULL
		`+islandReturning(), count, status, userID, islandID), &dto); err != nil {
		return domain.Island{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return domain.Island{}, err
	}
	return dto, nil
}

func (r *PG) RemoveFragments(ctx context.Context, userID, islandID int64, fragmentIDs []int64) (domain.Island, error) {
	if len(fragmentIDs) == 0 {
		return r.Find(ctx, userID, strconv.FormatInt(islandID, 10))
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Island{}, err
	}
	defer tx.Rollback(ctx)

	var sourceTagID *int64
	if err := tx.QueryRow(ctx, `SELECT source_tag_id FROM islands WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`,
		userID, islandID).Scan(&sourceTagID); err != nil {
		return domain.Island{}, err
	}
	if sourceTagID != nil {
		return domain.Island{}, ErrNotManualIsland
	}

	for _, fid := range fragmentIDs {
		if _, err := tx.Exec(ctx, `DELETE FROM island_fragments WHERE island_id=$1 AND fragment_id=$2`,
			islandID, fid); err != nil {
			return domain.Island{}, err
		}
	}

	var count int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM island_fragments WHERE island_id=$1`, islandID).Scan(&count); err != nil {
		return domain.Island{}, err
	}
	status := rules.StatusForFragmentCount(count)
	if status == "" {
		status = "star_point"
	}

	var dto domain.Island
	if err := scanIsland(tx.QueryRow(ctx, `UPDATE islands SET fragment_count=$1, status=$2, updated_at=now()
		WHERE user_id=$3 AND id=$4 AND deleted_at IS NULL
		`+islandReturning(), count, status, userID, islandID), &dto); err != nil {
		return domain.Island{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return domain.Island{}, err
	}
	return dto, nil
}

func (r *PG) MarkDormantIslands(ctx context.Context, userID int64) (int, error) {
	result, err := r.db.Exec(ctx, `UPDATE islands SET status='dormant', dormant_at=now(), updated_at=now()
		WHERE user_id=$1 AND status IN ('formed','relit') AND deleted_at IS NULL
		AND NOT EXISTS (
			SELECT 1 FROM island_fragments if2
			JOIN fragments f ON f.id=if2.fragment_id AND f.is_deleted=FALSE
			WHERE if2.island_id=islands.id AND f.created_at > now() - INTERVAL '30 days'
		)`, userID)
	if err != nil {
		return 0, err
	}
	return int(result.RowsAffected()), nil
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

func (r *PG) FragmentsByID(ctx context.Context, userID, islandID int64, limit int) ([]domain.FragmentPreview, error) {
	rows, err := r.db.Query(ctx, `SELECT f.id, f.public_id::text, f.content_text, COALESCE(f.emotion,'说不清'), f.created_at, f.updated_at
		FROM fragments f
		JOIN island_fragments isf ON isf.fragment_id = f.id
		WHERE f.user_id=$1 AND f.is_deleted=FALSE AND isf.island_id=$2
		ORDER BY f.created_at DESC LIMIT $3`, userID, islandID, limit)
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
