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
)

type Handler = handler.Handler
type UserDTO = domain.User
type TokenPair = domain.TokenPair

func New(db *pgxpool.Pool, cfg config.Config) *Handler {
	return handler.New(service.New(repository.NewPG(db), cfg))
}

func UserID(ctx context.Context) (int64, bool) {
	return authmw.UserID(ctx)
}

var _ http.Handler = (*Handler)(nil)
