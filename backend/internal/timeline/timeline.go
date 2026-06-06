package timeline

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/timeline/handler"
	"xiguang/backend/internal/timeline/repository"
	"xiguang/backend/internal/timeline/service"
)

type Handler = handler.Handler

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
