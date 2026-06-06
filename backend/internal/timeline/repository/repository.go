package repository

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5/pgxpool"

	fragmentdomain "xiguang/backend/internal/fragment/domain"
	"xiguang/backend/internal/timeline/domain"
)

type Repository interface {
	List(ctx context.Context, userID int64, query domain.Query) ([]domain.Fragment, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) List(ctx context.Context, userID int64, query domain.Query) ([]domain.Fragment, error) {
	rows, err := r.db.Query(ctx, fragmentSelectSQL+`
		WHERE f.user_id=$1 AND f.is_deleted=FALSE
		  AND ($2='' OR f.emotion=$2)
		  AND ($3='' OR EXISTS (
		    SELECT 1 FROM fragment_tags ft2
		    JOIN tags t2 ON t2.id=ft2.tag_id AND t2.deleted_at IS NULL
		    WHERE ft2.fragment_id=f.id AND t2.name=$3
		  ))
		GROUP BY f.id
		ORDER BY f.created_at DESC, f.id DESC LIMIT $4`, userID, query.Emotion, query.Tag, query.Limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []domain.Fragment{}
	for rows.Next() {
		var dto fragmentdomain.Fragment
		if err := scanFragment(rows, &dto); err != nil {
			return nil, err
		}
		items = append(items, dto)
	}
	return items, rows.Err()
}

type fragmentScanner interface {
	Scan(dest ...any) error
}

const fragmentSelectSQL = `SELECT f.id, f.public_id::text, f.user_id, f.content_text, COALESCE(f.emotion, '说不清'), f.status::text,
	COALESCE(jsonb_agg(DISTINCT t.name) FILTER (WHERE t.name IS NOT NULL), '[]'::jsonb) AS tags,
	COALESCE(jsonb_agg(DISTINCT m.object_key) FILTER (WHERE m.object_key IS NOT NULL), '[]'::jsonb) AS media_urls,
	f.is_deleted, f.server_rev, f.created_at, f.updated_at
	FROM fragments f
	LEFT JOIN fragment_tags ft ON ft.fragment_id=f.id
	LEFT JOIN tags t ON t.id=ft.tag_id AND t.deleted_at IS NULL
	LEFT JOIN media_files m ON m.fragment_id=f.id AND m.deleted_at IS NULL`

func scanFragment(scanner fragmentScanner, dto *fragmentdomain.Fragment) error {
	return scanner.Scan(&dto.ID, &dto.PublicID, &dto.UserID, &dto.ContentText, &dto.Emotion, &dto.Status,
		(*jsonRawSlice)(&dto.Tags), (*jsonRawSlice)(&dto.MediaURLs), &dto.IsDeleted, &dto.ServerRev, &dto.CreatedAt, &dto.UpdatedAt)
}

type jsonRawSlice []string

func (s *jsonRawSlice) Scan(value any) error {
	switch v := value.(type) {
	case []byte:
		return json.Unmarshal(v, s)
	case string:
		return json.Unmarshal([]byte(v), s)
	default:
		return nil
	}
}
