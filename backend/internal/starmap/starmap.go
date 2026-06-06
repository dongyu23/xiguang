package starmap

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/starmap/handler"
	"xiguang/backend/internal/starmap/repository"
	"xiguang/backend/internal/starmap/service"
)

type Handler = handler.Handler

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
