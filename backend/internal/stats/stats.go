package stats

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/stats/handler"
	"xiguang/backend/internal/stats/repository"
	"xiguang/backend/internal/stats/service"
)

type Handler = handler.Handler

func New(db *pgxpool.Pool) *Handler {
	repo := repository.NewPG(db)
	return handler.New(service.New(repo))
}

var _ http.Handler = (*Handler)(nil)
