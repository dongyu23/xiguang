package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/app_release/domain"
)

// ErrNotFound 表示根据公开 ID 找不到记录。
var ErrNotFound = errors.New("release_not_found")

type Repository interface {
	Insert(ctx context.Context, params domain.PublishParams) (domain.Release, error)
	FindLatest(ctx context.Context, q domain.LatestQuery) (domain.Release, error)
	FindByPublicID(ctx context.Context, publicID string) (domain.Release, error)
	List(ctx context.Context, includeDeleted bool, limit int) ([]domain.Release, error)
	UpdatePolicy(ctx context.Context, publicID string, params domain.UpdatePolicyParams) (domain.Release, error)
	SoftDelete(ctx context.Context, publicID string) (bool, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

const selectColumns = `id, public_id::text, channel::text, platform::text, version, build_number,
	min_supported_build, apk_file_name, apk_size_bytes, sha256, release_note, force_update,
	published_at, created_at, updated_at`

func (r *PG) Insert(ctx context.Context, p domain.PublishParams) (domain.Release, error) {
	var dto domain.Release
	err := r.db.QueryRow(ctx, `INSERT INTO app_releases
		(channel, platform, version, build_number, min_supported_build,
		 apk_file_name, apk_size_bytes, sha256, release_note, force_update)
		VALUES ($1::release_channel, $2::release_platform, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING `+selectColumns,
		p.Channel, p.Platform, p.Version, p.BuildNumber, p.MinSupportedBuild,
		p.APKFileName, p.APKSizeBytes, p.SHA256, p.ReleaseNote, p.ForceUpdate,
	).Scan(
		&dto.ID, &dto.PublicID, &dto.Channel, &dto.Platform, &dto.Version, &dto.BuildNumber,
		&dto.MinSupportedBuild, &dto.APKFileName, &dto.APKSizeBytes, &dto.SHA256,
		&dto.ReleaseNote, &dto.ForceUpdate, &dto.PublishedAt, &dto.CreatedAt, &dto.UpdatedAt,
	)
	return dto, err
}

func (r *PG) FindLatest(ctx context.Context, q domain.LatestQuery) (domain.Release, error) {
	var dto domain.Release
	err := r.db.QueryRow(ctx, `SELECT `+selectColumns+`
		FROM app_releases
		WHERE channel=$1::release_channel
		  AND platform=$2::release_platform
		  AND deleted_at IS NULL
		ORDER BY build_number DESC
		LIMIT 1`,
		q.Channel, q.Platform,
	).Scan(
		&dto.ID, &dto.PublicID, &dto.Channel, &dto.Platform, &dto.Version, &dto.BuildNumber,
		&dto.MinSupportedBuild, &dto.APKFileName, &dto.APKSizeBytes, &dto.SHA256,
		&dto.ReleaseNote, &dto.ForceUpdate, &dto.PublishedAt, &dto.CreatedAt, &dto.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Release{}, ErrNotFound
	}
	return dto, err
}

func (r *PG) FindByPublicID(ctx context.Context, publicID string) (domain.Release, error) {
	var dto domain.Release
	err := r.db.QueryRow(ctx, `SELECT `+selectColumns+`
		FROM app_releases WHERE public_id=$1::uuid AND deleted_at IS NULL`, publicID,
	).Scan(
		&dto.ID, &dto.PublicID, &dto.Channel, &dto.Platform, &dto.Version, &dto.BuildNumber,
		&dto.MinSupportedBuild, &dto.APKFileName, &dto.APKSizeBytes, &dto.SHA256,
		&dto.ReleaseNote, &dto.ForceUpdate, &dto.PublishedAt, &dto.CreatedAt, &dto.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Release{}, ErrNotFound
	}
	return dto, err
}

func (r *PG) List(ctx context.Context, includeDeleted bool, limit int) ([]domain.Release, error) {
	where := "WHERE deleted_at IS NULL"
	if includeDeleted {
		where = ""
	}
	rows, err := r.db.Query(ctx, `SELECT `+selectColumns+` FROM app_releases `+where+`
		ORDER BY published_at DESC LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []domain.Release{}
	for rows.Next() {
		var dto domain.Release
		if err := rows.Scan(
			&dto.ID, &dto.PublicID, &dto.Channel, &dto.Platform, &dto.Version, &dto.BuildNumber,
			&dto.MinSupportedBuild, &dto.APKFileName, &dto.APKSizeBytes, &dto.SHA256,
			&dto.ReleaseNote, &dto.ForceUpdate, &dto.PublishedAt, &dto.CreatedAt, &dto.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, dto)
	}
	return items, rows.Err()
}

func (r *PG) UpdatePolicy(ctx context.Context, publicID string, p domain.UpdatePolicyParams) (domain.Release, error) {
	// 用 COALESCE 的方式让 nil 字段保持原值，避免拼动态 SQL。
	var dto domain.Release
	err := r.db.QueryRow(ctx, `UPDATE app_releases SET
		release_note        = COALESCE($2, release_note),
		force_update        = COALESCE($3, force_update),
		min_supported_build = COALESCE($4, min_supported_build),
		updated_at = now()
		WHERE public_id=$1::uuid AND deleted_at IS NULL
		RETURNING `+selectColumns,
		publicID, p.ReleaseNote, p.ForceUpdate, p.MinSupportedBuild,
	).Scan(
		&dto.ID, &dto.PublicID, &dto.Channel, &dto.Platform, &dto.Version, &dto.BuildNumber,
		&dto.MinSupportedBuild, &dto.APKFileName, &dto.APKSizeBytes, &dto.SHA256,
		&dto.ReleaseNote, &dto.ForceUpdate, &dto.PublishedAt, &dto.CreatedAt, &dto.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Release{}, ErrNotFound
	}
	return dto, err
}

func (r *PG) SoftDelete(ctx context.Context, publicID string) (bool, error) {
	result, err := r.db.Exec(ctx, `UPDATE app_releases SET deleted_at=now(), updated_at=now()
		WHERE public_id=$1::uuid AND deleted_at IS NULL`, publicID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}
