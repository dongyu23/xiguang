package media

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/media/handler"
	"xiguang/backend/internal/media/repository"
	"xiguang/backend/internal/media/service"
)

type Handler = handler.Handler

func New(db *pgxpool.Pool, cfg config.Config) *Handler {
	return handler.New(service.New(repository.NewPG(db), cfg))
}

var _ http.Handler = (*Handler)(nil)
