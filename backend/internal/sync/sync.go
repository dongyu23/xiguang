package sync

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/sync/domain"
	"xiguang/backend/internal/sync/handler"
	"xiguang/backend/internal/sync/repository"
	"xiguang/backend/internal/sync/service"
)

type Handler = handler.Handler
type PushRequest = domain.PushRequest
type PullResponse = domain.PullResponse

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

var _ http.Handler = (*Handler)(nil)
