package island

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/handler"
	"xiguang/backend/internal/island/repository"
	"xiguang/backend/internal/island/service"
)

type Handler = handler.Handler
type DTO = domain.Island

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
