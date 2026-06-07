package repository

import (
	"context"
	"encoding/json"
	"path/filepath"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/fragment/domain"
	"xiguang/backend/internal/island/rules"
)

type Repository interface {
	Create(ctx context.Context, userID int64, text, emotion, status string, tags, media []string) (domain.Fragment, error)
	Update(ctx context.Context, userID int64, id int64, text, emotion, status string, tags []string, media *[]string) (domain.Fragment, error)
	Delete(ctx context.Context, userID, id int64) (bool, error)
	List(ctx context.Context, userID int64, query domain.ListQuery) ([]domain.Fragment, error)
	FindByID(ctx context.Context, userID, id int64) (domain.Fragment, error)
	LogCreate(ctx context.Context, userID int64, clientOpID string, dto domain.Fragment) error
	FindConfirmedMedia(ctx context.Context, userID int64, objectKeys []string) (map[string]bool, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) Create(ctx context.Context, userID int64, text, emotion, status string, tags, media []string) (domain.Fragment, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Fragment{}, err
	}
	defer tx.Rollback(ctx)

	var dto domain.Fragment
	err = tx.QueryRow(ctx, `INSERT INTO fragments(user_id, content_text, emotion, status, updated_at)
		VALUES($1,$2,$3,$4,now())
		RETURNING id, public_id::text, user_id, content_text, emotion, status::text, is_deleted, server_rev, created_at, updated_at`,
		userID, text, emotion, status).Scan(
		&dto.ID, &dto.PublicID, &dto.UserID, &dto.ContentText, &dto.Emotion, &dto.Status,
		&dto.IsDeleted, &dto.ServerRev, &dto.CreatedAt, &dto.UpdatedAt)
	if err != nil {
		return domain.Fragment{}, err
	}
	if err := r.replaceFragmentTags(ctx, tx, userID, dto.ID, tags); err != nil {
		return domain.Fragment{}, err
	}
	if err := r.replaceFragmentMedia(ctx, tx, userID, dto.ID, media); err != nil {
		return domain.Fragment{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.Fragment{}, err
	}
	dto.Tags = tags
	dto.MediaURLs = media
	return dto, nil
}

func (r *PG) Update(ctx context.Context, userID int64, id int64, text, emotion, status string, tags []string, media *[]string) (domain.Fragment, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Fragment{}, err
	}
	defer tx.Rollback(ctx)

	var updatedID int64
	err = tx.QueryRow(ctx, `UPDATE fragments
		SET content_text=$3, emotion=$4, status=$5, updated_at=now()
		WHERE user_id=$1 AND id=$2 AND is_deleted=FALSE
		RETURNING id`, userID, id, text, emotion, status).Scan(&updatedID)
	if err != nil {
		return domain.Fragment{}, err
	}
	if err := r.replaceFragmentTags(ctx, tx, userID, updatedID, tags); err != nil {
		return domain.Fragment{}, err
	}
	if media != nil {
		if err := r.replaceFragmentMedia(ctx, tx, userID, updatedID, *media); err != nil {
			return domain.Fragment{}, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.Fragment{}, err
	}
	return r.FindByID(ctx, userID, updatedID)
}

func (r *PG) Delete(ctx context.Context, userID, id int64) (bool, error) {
	tag, err := r.db.Exec(ctx, `UPDATE fragments SET is_deleted=TRUE, deleted_at=now(), updated_at=now()
		WHERE user_id=$1 AND id=$2 AND is_deleted=FALSE`, userID, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *PG) List(ctx context.Context, userID int64, query domain.ListQuery) ([]domain.Fragment, error) {
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
		var dto domain.Fragment
		if err := scanFragment(rows, &dto); err != nil {
			return nil, err
		}
		items = append(items, dto)
	}
	return items, rows.Err()
}

func (r *PG) FindByID(ctx context.Context, userID, id int64) (domain.Fragment, error) {
	var dto domain.Fragment
	err := scanFragment(r.db.QueryRow(ctx, fragmentSelectSQL+`
		WHERE f.user_id=$1 AND f.id=$2 AND f.is_deleted=FALSE
		GROUP BY f.id`, userID, id), &dto)
	return dto, err
}

func (r *PG) LogCreate(ctx context.Context, userID int64, clientOpID string, dto domain.Fragment) error {
	_, err := r.db.Exec(ctx, `INSERT INTO oplog(user_id, client_op_id, entity_type, op_type, entity_id, entity_public_id, payload)
		VALUES($1,$2,'fragment','create',$3,$4,$5) ON CONFLICT DO NOTHING`,
		userID, clientOpID, dto.ID, dto.PublicID, mustJSON(dto))
	return err
}

func (r *PG) FindConfirmedMedia(ctx context.Context, userID int64, objectKeys []string) (map[string]bool, error) {
	confirmed := map[string]bool{}
	if len(objectKeys) == 0 {
		return confirmed, nil
	}
	rows, err := r.db.Query(ctx, `SELECT object_key FROM media_files
		WHERE user_id=$1 AND object_key=ANY($2) AND deleted_at IS NULL`, userID, objectKeys)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var objectKey string
		if err := rows.Scan(&objectKey); err != nil {
			return nil, err
		}
		confirmed[objectKey] = true
	}
	return confirmed, rows.Err()
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

func scanFragment(scanner fragmentScanner, dto *domain.Fragment) error {
	return scanner.Scan(&dto.ID, &dto.PublicID, &dto.UserID, &dto.ContentText, &dto.Emotion, &dto.Status,
		(*jsonRawSlice)(&dto.Tags), (*jsonRawSlice)(&dto.MediaURLs), &dto.IsDeleted, &dto.ServerRev, &dto.CreatedAt, &dto.UpdatedAt)
}

func (r *PG) replaceFragmentTags(ctx context.Context, tx pgx.Tx, userID, fragmentID int64, tags []string) error {
	if _, err := tx.Exec(ctx, `DELETE FROM fragment_tags WHERE fragment_id=$1`, fragmentID); err != nil {
		return err
	}
	for _, tag := range tags {
		var tagID int64
		if err := tx.QueryRow(ctx, `INSERT INTO tags(user_id,name,use_count) VALUES($1,$2,1)
			ON CONFLICT(user_id,name) WHERE deleted_at IS NULL DO UPDATE SET use_count=tags.use_count+1, updated_at=now()
			RETURNING id`, userID, tag).Scan(&tagID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `INSERT INTO fragment_tags(fragment_id, tag_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, fragmentID, tagID); err != nil {
			return err
		}
		if err := r.growIsland(ctx, tx, userID, tagID, tag); err != nil {
			return err
		}
	}
	return nil
}

func (r *PG) replaceFragmentMedia(ctx context.Context, tx pgx.Tx, userID, fragmentID int64, media []string) error {
	if _, err := tx.Exec(ctx, `UPDATE media_files SET deleted_at=now()
		WHERE user_id=$1 AND fragment_id=$2 AND deleted_at IS NULL`, userID, fragmentID); err != nil {
		return err
	}
	for _, raw := range media {
		objectKey := strings.TrimSpace(raw)
		if objectKey == "" {
			continue
		}
		mime := mimeFromObjectKey(objectKey)
		fileName := fileNameFromObjectKey(objectKey, mime)
		if _, err := tx.Exec(ctx, `INSERT INTO media_files(user_id, fragment_id, media_type, object_key, file_name, mime_type)
			VALUES($1,$2,$3,$4,$5,$6)
			ON CONFLICT DO NOTHING`, userID, fragmentID, mediaTypeFromMime(mime), objectKey, fileName, mime); err != nil {
			return err
		}
	}
	return nil
}

func fileNameFromObjectKey(objectKey, mime string) string {
	if strings.HasPrefix(objectKey, "data:image/") ||
		strings.HasPrefix(objectKey, "data:audio/") {
		return "light-media" + extFromMime(mime)
	}
	fileName := filepath.Base(objectKey)
	if fileName == "." || fileName == string(filepath.Separator) || fileName == "" {
		return "light-media" + extFromMime(mime)
	}
	if len(fileName) > 512 {
		return fileName[:512]
	}
	return fileName
}

func mimeFromObjectKey(objectKey string) string {
	if strings.HasPrefix(objectKey, "data:image/") ||
		strings.HasPrefix(objectKey, "data:audio/") {
		header := strings.SplitN(objectKey, ",", 2)[0]
		mime := strings.TrimPrefix(strings.SplitN(header, ";", 2)[0], "data:")
		if strings.HasPrefix(mime, "image/") ||
			strings.HasPrefix(mime, "audio/") {
			return mime
		}
	}
	return mimeFromName(filepath.Base(objectKey))
}

func mimeFromName(fileName string) string {
	switch strings.ToLower(filepath.Ext(fileName)) {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	case ".m4a":
		return "audio/mp4"
	case ".aac":
		return "audio/aac"
	case ".mp3":
		return "audio/mpeg"
	case ".wav":
		return "audio/wav"
	case ".ogg", ".opus":
		return "audio/ogg"
	default:
		return "image/jpeg"
	}
}

func extFromMime(mime string) string {
	switch mime {
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	case "audio/wav":
		return ".wav"
	case "audio/mpeg":
		return ".mp3"
	case "audio/mp4":
		return ".m4a"
	case "audio/aac":
		return ".aac"
	case "audio/ogg":
		return ".ogg"
	default:
		return ".jpg"
	}
}

func mediaTypeFromMime(mime string) string {
	if strings.HasPrefix(mime, "audio/") {
		return "audio"
	}
	return "image"
}

func (r *PG) growIsland(ctx context.Context, tx pgx.Tx, userID, tagID int64, tagName string) error {
	var count int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM fragment_tags ft
		JOIN fragments f ON f.id=ft.fragment_id AND f.is_deleted=FALSE
		WHERE f.user_id=$1 AND ft.tag_id=$2`, userID, tagID).Scan(&count); err != nil {
		return err
	}
	if count < rules.StarPointThreshold {
		return nil
	}

	// Read current island status to handle dormant→relit→formed transitions.
	// FOR UPDATE serializes concurrent island growth for the same tag.
	var currentStatus string
	_ = tx.QueryRow(ctx, `SELECT status::text FROM islands
		WHERE user_id=$1 AND source_tag_id=$2 AND deleted_at IS NULL
		FOR UPDATE`,
		userID, tagID).Scan(&currentStatus)

	status := rules.NextStatus(currentStatus, count, true)

	var islandID int64
	upsertSQL := `INSERT INTO islands(user_id, name, status, source_tag_id, fragment_count)
		VALUES($1,$2,$3,$4,$5)
		ON CONFLICT(user_id, source_tag_id) WHERE deleted_at IS NULL DO UPDATE
		SET status=EXCLUDED.status, fragment_count=EXCLUDED.fragment_count, updated_at=now()`
	upsertArgs := []any{userID, tagName, status, tagID, count}

	// Handle timestamp columns for dormant/relit transitions.
	if currentStatus == "dormant" && status == "relit" {
		upsertSQL = `INSERT INTO islands(user_id, name, status, source_tag_id, fragment_count, relit_at)
			VALUES($1,$2,$3,$4,$5,now())
			ON CONFLICT(user_id, source_tag_id) WHERE deleted_at IS NULL DO UPDATE
			SET status=EXCLUDED.status, fragment_count=EXCLUDED.fragment_count,
			    relit_at=now(), updated_at=now()`
	} else if status == "formed" {
		upsertSQL = `INSERT INTO islands(user_id, name, status, source_tag_id, fragment_count)
			VALUES($1,$2,$3,$4,$5)
			ON CONFLICT(user_id, source_tag_id) WHERE deleted_at IS NULL DO UPDATE
			SET status=EXCLUDED.status, fragment_count=EXCLUDED.fragment_count,
			    dormant_at=NULL, relit_at=NULL, updated_at=now()`
	}

	if err := tx.QueryRow(ctx, upsertSQL, upsertArgs...).Scan(&islandID); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `INSERT INTO island_fragments(island_id, fragment_id)
		SELECT $1, ft.fragment_id FROM fragment_tags ft
		JOIN fragments f ON f.id=ft.fragment_id AND f.is_deleted=FALSE
		WHERE f.user_id=$2 AND ft.tag_id=$3
		ON CONFLICT DO NOTHING`, islandID, userID, tagID)
	return err
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

func mustJSON(value any) string {
	buf, _ := json.Marshal(value)
	return string(buf)
}
