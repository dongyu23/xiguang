package fragment

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/fragment/domain"
	"xiguang/backend/internal/fragment/handler"
	"xiguang/backend/internal/fragment/repository"
	"xiguang/backend/internal/fragment/service"
	"xiguang/backend/internal/relation"
)

type Handler = handler.Handler
type DTO = domain.Fragment

func New(db *pgxpool.Pool) *Handler {
	weave := func(ctx context.Context, userID, sourceFragmentID, targetFragmentID int64, relationType, note string) (any, error) {
		return relation.Create(ctx, db, userID, sourceFragmentID, targetFragmentID, relationType, note)
	}
	return handler.New(service.New(repository.NewPG(db), weave))
}

var _ http.Handler = (*Handler)(nil)
