package tag

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/tag/domain"
	"xiguang/backend/internal/tag/handler"
	"xiguang/backend/internal/tag/repository"
	"xiguang/backend/internal/tag/service"
)

type Handler = handler.Handler
type DTO = domain.Tag

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
