package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/auth/domain"
)

type Repository interface {
	CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error)
	FindByUsername(ctx context.Context, username string) (domain.User, error)
	FindByID(ctx context.Context, id int64) (domain.User, error)
	UpdateUser(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error)
	InsertRefreshToken(ctx context.Context, userID int64, tokenHash string, expiresAt time.Time) error
	FindRefreshUserID(ctx context.Context, tokenHash string) (int64, error)
	RotateRefreshToken(ctx context.Context, oldTokenHash, newTokenHash string, expiresAt time.Time) (int64, error)
}

type PG struct {
	db *pgxpool.Pool
}

func NewPG(db *pgxpool.Pool) *PG {
	return &PG{db: db}
}

func (r *PG) CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error) {
	var user domain.User
	err := r.db.QueryRow(ctx, `INSERT INTO users(username,password_hash,nickname) VALUES($1,$2,$3)
		RETURNING id, public_id::text, username, nickname, avatar_key, ai_enabled, privacy_mode, created_at`,
		username, passwordHash, nickname).Scan(&user.ID, &user.PublicID, &user.Username, &user.Nickname, &user.AvatarKey, &user.AIEnabled, &user.PrivacyMode, &user.CreatedAt)
	return user, err
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
		    ai_enabled=$4, privacy_mode=$5, updated_at=now()
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
