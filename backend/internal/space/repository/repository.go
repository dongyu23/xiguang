package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/space/domain"
)

type Repository interface {
	Config(context.Context, int64) (domain.Config, error)
	Update(context.Context, int64, domain.Config) (domain.Config, error)
}

type PG struct{ db *pgxpool.Pool }

func NewPG(db *pgxpool.Pool) *PG { return &PG{db: db} }

func (r *PG) Config(ctx context.Context, userID int64) (domain.Config, error) {
	_, err := r.db.Exec(ctx, `INSERT INTO user_space_configs(user_id) VALUES($1) ON CONFLICT(user_id) DO NOTHING`, userID)
	if err != nil {
		return domain.Config{}, err
	}
	var config domain.Config
	err = r.db.QueryRow(ctx, `SELECT theme,breathing_motion,white_noise_enabled FROM user_space_configs WHERE user_id=$1`, userID).
		Scan(&config.Theme, &config.BreathingMotion, &config.WhiteNoiseEnabled)
	return config, err
}

func (r *PG) Update(ctx context.Context, userID int64, config domain.Config) (domain.Config, error) {
	err := r.db.QueryRow(ctx, `INSERT INTO user_space_configs(user_id,theme,breathing_motion,white_noise_enabled)
		VALUES($1,$2,$3,$4) ON CONFLICT(user_id) DO UPDATE SET theme=excluded.theme,
		breathing_motion=excluded.breathing_motion,white_noise_enabled=excluded.white_noise_enabled,updated_at=now()
		RETURNING theme,breathing_motion,white_noise_enabled`, userID, config.Theme, config.BreathingMotion, config.WhiteNoiseEnabled).
		Scan(&config.Theme, &config.BreathingMotion, &config.WhiteNoiseEnabled)
	return config, err
}
