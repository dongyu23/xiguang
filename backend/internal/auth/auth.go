package auth

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/auth/domain"
	"xiguang/backend/internal/auth/handler"
	authmw "xiguang/backend/internal/auth/middleware"
	"xiguang/backend/internal/auth/repository"
	"xiguang/backend/internal/auth/service"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
)

type Handler = handler.Handler
type UserDTO = domain.User
type TokenPair = domain.TokenPair

func New(db *pgxpool.Pool, cfg config.Config) *Handler {
	repo := repository.NewPG(db)
	provider, err := storage.NewMinIOProvider(cfg)
	if err != nil {
		return handler.New(service.New(repo, cfg))
	}
	return handler.New(service.New(repo, cfg, provider))
}

func UserID(ctx context.Context) (int64, bool) {
	return authmw.UserID(ctx)
}

var _ http.Handler = (*Handler)(nil)
