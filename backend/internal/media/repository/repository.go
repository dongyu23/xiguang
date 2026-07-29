package repository

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/media/domain"
)

type Repository interface {
	Confirm(ctx context.Context, userID int64, req domain.ConfirmRequest) (domain.MediaFile, error)
	Create(ctx context.Context, userID int64, req domain.CreateMediaRequest) (domain.MediaFile, error)
	Get(ctx context.Context, userID, mediaID int64) (domain.MediaFile, error)
	GetByObjectKey(ctx context.Context, userID int64, objectKey string) (domain.MediaFile, error)
	FindByObjectKeys(ctx context.Context, userID int64, objectKeys []string) ([]domain.MediaFile, error)
	Delete(ctx context.Context, userID, mediaID int64) (bool, error)
}

func (r *PG) FindByObjectKeys(ctx context.Context, userID int64, objectKeys []string) ([]domain.MediaFile, error) {
	rows, err := r.db.Query(ctx, `SELECT object_key, file_name, mime_type, file_size
		FROM media_files
		WHERE user_id=$1 AND object_key=ANY($2) AND deleted_at IS NULL`, userID, objectKeys)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]domain.MediaFile, 0, len(objectKeys))
	for rows.Next() {
		var item domain.MediaFile
		if err := rows.Scan(&item.ObjectKey, &item.FileName, &item.MimeType, &item.FileSize); err != nil {
			return nil, err
		}
		item.FileURL = "/media/" + item.ObjectKey
		items = append(items, item)
	}
	return items, rows.Err()
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) Confirm(ctx context.Context, userID int64, req domain.ConfirmRequest) (domain.MediaFile, error) {
	var item domain.MediaFile
	err := r.db.QueryRow(ctx, `INSERT INTO media_files(user_id, fragment_id, media_type, object_key, file_name, file_size, mime_type)
		SELECT $1, f.id, $3, $4, $5, $6, $7
		FROM fragments f
		WHERE f.user_id=$1 AND f.id=$2 AND f.is_deleted=FALSE
		RETURNING id, public_id::text`,
		userID, req.FragmentID, mediaType(req.MimeType), req.ObjectKey, req.FileName, req.FileSize, req.MimeType).
		Scan(&item.ID, &item.PublicID)
	item.ObjectKey = req.ObjectKey
	item.FileName = req.FileName
	item.MimeType = req.MimeType
	item.FileSize = req.FileSize
	item.FileURL = "/media/" + req.ObjectKey
	return item, err
}

func (r *PG) Create(ctx context.Context, userID int64, req domain.CreateMediaRequest) (domain.MediaFile, error) {
	var item domain.MediaFile
	err := r.db.QueryRow(ctx, `INSERT INTO media_files(user_id, fragment_id, media_type, object_key, file_name, file_size, mime_type)
		SELECT $1, f.id, $3, $4, $5, $6, $7
		FROM fragments f
		WHERE f.user_id=$1 AND f.id=$2 AND f.is_deleted=FALSE
		RETURNING id, public_id::text`,
		userID, req.FragmentID, mediaType(req.MimeType), req.ObjectKey, req.FileName, req.FileSize, req.MimeType).
		Scan(&item.ID, &item.PublicID)
	item.ObjectKey = req.ObjectKey
	item.FileName = req.FileName
	item.MimeType = req.MimeType
	item.FileSize = req.FileSize
	item.FileURL = "/media/" + req.ObjectKey
	return item, err
}

func (r *PG) Get(ctx context.Context, userID, mediaID int64) (domain.MediaFile, error) {
	item := domain.MediaFile{ID: mediaID}
	err := r.db.QueryRow(ctx, `SELECT object_key, file_name, mime_type, file_size
		FROM media_files WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, mediaID).
		Scan(&item.ObjectKey, &item.FileName, &item.MimeType, &item.FileSize)
	item.FileURL = "/media/" + item.ObjectKey
	return item, err
}

func (r *PG) GetByObjectKey(ctx context.Context, userID int64, objectKey string) (domain.MediaFile, error) {
	var item domain.MediaFile
	err := r.db.QueryRow(ctx, `SELECT id,public_id::text,object_key,file_name,mime_type,file_size FROM media_files
		WHERE user_id=$1 AND object_key=$2 AND deleted_at IS NULL`, userID, objectKey).Scan(&item.ID, &item.PublicID, &item.ObjectKey, &item.FileName, &item.MimeType, &item.FileSize)
	item.FileURL = "/media/" + item.ObjectKey
	return item, err
}

func (r *PG) Delete(ctx context.Context, userID, mediaID int64) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE media_files SET deleted_at=now() WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL`, userID, mediaID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

func mediaType(mime string) string {
	if strings.HasPrefix(mime, "audio/") {
		return "audio"
	}
	return "image"
}
