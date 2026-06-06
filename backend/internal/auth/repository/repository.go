package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/auth/domain"
)

type Repository interface {
	CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error)
	EnsureDefaultIsland(ctx context.Context, userID int64) error
	FindByUsername(ctx context.Context, username string) (domain.User, error)
	FindByID(ctx context.Context, id int64) (domain.User, error)
	UpdateUser(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error)
	InsertRefreshToken(ctx context.Context, userID int64, tokenHash string, expiresAt time.Time) error
	FindRefreshUserID(ctx context.Context, tokenHash string) (int64, error)
	RotateRefreshToken(ctx context.Context, oldTokenHash, newTokenHash string, expiresAt time.Time) (int64, error)
}

const (
	defaultSeedIslandName   = "隙光初见"
	defaultSeedFragmentText = "今天下载了隙光APP，好开心"
	defaultSeedEmotion      = "开心"
	defaultSeedStatus       = "twilight"
	defaultSeedDescription  = "第一次打开隙光时留下的真实记录。"
)

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback(ctx)

	var user domain.User
	err = tx.QueryRow(ctx, `INSERT INTO users(username,password_hash,nickname) VALUES($1,$2,$3)
		RETURNING id, public_id::text, username, nickname, avatar_key, ai_enabled, privacy_mode, created_at`,
		username, passwordHash, nickname).Scan(&user.ID, &user.PublicID, &user.Username, &user.Nickname, &user.AvatarKey, &user.AIEnabled, &user.PrivacyMode, &user.CreatedAt)
	if err != nil {
		return domain.User{}, err
	}
	if err := seedDefaultIsland(ctx, tx, user.ID); err != nil {
		return domain.User{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.User{}, err
	}
	return user, nil
}

type execQuerier interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func seedDefaultIsland(ctx context.Context, tx execQuerier, userID int64) error {
	var fragmentID int64
	err := tx.QueryRow(ctx, `SELECT f.id FROM fragments f
		JOIN fragment_tags ft ON ft.fragment_id=f.id
		JOIN tags t ON t.id=ft.tag_id AND t.deleted_at IS NULL
		WHERE f.user_id=$1 AND f.is_deleted=FALSE AND t.name=$2
		ORDER BY f.created_at ASC, f.id ASC LIMIT 1`, userID, defaultSeedIslandName).Scan(&fragmentID)
	if err != nil {
		if err != pgx.ErrNoRows {
			return err
		}
		if err := tx.QueryRow(ctx, `INSERT INTO fragments(user_id, content_text, emotion, status, updated_at)
			VALUES($1,$2,$3,$4,now()) RETURNING id`,
			userID, defaultSeedFragmentText, defaultSeedEmotion, defaultSeedStatus).Scan(&fragmentID); err != nil {
			return err
		}
	}

	var tagID int64
	if err := tx.QueryRow(ctx, `INSERT INTO tags(user_id,name,use_count)
		VALUES($1,$2,1)
		ON CONFLICT(user_id,name) WHERE deleted_at IS NULL
		DO UPDATE SET use_count=tags.use_count+1, updated_at=now()
		RETURNING id`, userID, defaultSeedIslandName).Scan(&tagID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO fragment_tags(fragment_id, tag_id)
		VALUES($1,$2) ON CONFLICT DO NOTHING`, fragmentID, tagID); err != nil {
		return err
	}

	var islandID int64
	if err := tx.QueryRow(ctx, `INSERT INTO islands(user_id, name, description, cover_fragment_id, status, source_tag_id, fragment_count)
		VALUES($1,$2,$3,$4,'star_point',$5,1)
		ON CONFLICT(user_id, source_tag_id) WHERE deleted_at IS NULL
		DO UPDATE SET fragment_count=1, cover_fragment_id=EXCLUDED.cover_fragment_id, updated_at=now()
		RETURNING id`, userID, defaultSeedIslandName, defaultSeedDescription, fragmentID, tagID).Scan(&islandID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO island_fragments(island_id, fragment_id)
		VALUES($1,$2) ON CONFLICT DO NOTHING`, islandID, fragmentID); err != nil {
		return err
	}
	return nil
}

func (r *PG) EnsureDefaultIsland(ctx context.Context, userID int64) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := seedDefaultIsland(ctx, tx, userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (r *PG) FindByUsername(ctx context.Context, username string) (domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx, `SELECT id, public_id::text, username, nickname, avatar_key, ai_enabled, privacy_mode, created_at, password_hash
		FROM users WHERE username=$1`, username).
		Scan(&user.ID, &user.PublicID, &user.Username, &user.Nickname, &user.AvatarKey, &user.AIEnabled, &user.PrivacyMode, &user.CreatedAt, &user.PasswordHash)
	return user, err
}

func (r *PG) FindByID(ctx context.Context, id int64) (domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx, `SELECT id, public_id::text, username, nickname, avatar_key, ai_enabled, privacy_mode, created_at
		FROM users WHERE id=$1`, id).
		Scan(&user.ID, &user.PublicID, &user.Username, &user.Nickname, &user.AvatarKey, &user.AIEnabled, &user.PrivacyMode, &user.CreatedAt)
	return user, err
}

func (r *PG) UpdateUser(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx, `UPDATE users
		SET nickname=COALESCE(NULLIF($2,''), nickname), avatar_key=COALESCE(NULLIF($3,''), avatar_key),
		    ai_enabled=COALESCE($4, ai_enabled), privacy_mode=$5, updated_at=now()
		WHERE id=$1 AND deleted_at IS NULL
		RETURNING id, public_id::text, username, nickname, avatar_key, ai_enabled, privacy_mode, created_at`,
		id, params.Nickname, params.AvatarKey, params.AIEnabled, params.PrivacyMode).
		Scan(&user.ID, &user.PublicID, &user.Username, &user.Nickname, &user.AvatarKey, &user.AIEnabled, &user.PrivacyMode, &user.CreatedAt)
	return user, err
}

func (r *PG) InsertRefreshToken(ctx context.Context, userID int64, tokenHash string, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx, `INSERT INTO refresh_tokens(user_id, token_hash, expires_at) VALUES($1,$2,$3)`,
		userID, tokenHash, expiresAt)
	return err
}

func (r *PG) FindRefreshUserID(ctx context.Context, tokenHash string) (int64, error) {
	var userID int64
	err := r.db.QueryRow(ctx, `SELECT user_id FROM refresh_tokens WHERE token_hash=$1 AND revoked_at IS NULL AND expires_at > now()`, tokenHash).Scan(&userID)
	return userID, err
}

func (r *PG) RotateRefreshToken(ctx context.Context, oldTokenHash, newTokenHash string, expiresAt time.Time) (int64, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	var userID int64
	err = tx.QueryRow(ctx, `UPDATE refresh_tokens
		SET revoked_at=now()
		WHERE token_hash=$1 AND revoked_at IS NULL AND expires_at > now()
		RETURNING user_id`, oldTokenHash).Scan(&userID)
	if err != nil {
		return 0, err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO refresh_tokens(user_id, token_hash, expires_at) VALUES($1,$2,$3)`,
		userID, newTokenHash, expiresAt); err != nil {
		return 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return userID, nil
}
