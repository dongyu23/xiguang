package relation

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/relation/domain"
	"xiguang/backend/internal/relation/handler"
	"xiguang/backend/internal/relation/repository"
	"xiguang/backend/internal/relation/service"
)

type Handler = handler.Handler
type DTO = domain.Relation

func New(db *pgxpool.Pool) *Handler {
	return handler.New(service.New(repository.NewPG(db)))
}

func Create(ctx context.Context, db *pgxpool.Pool, userID, sourceFragmentID, targetFragmentID int64, relationType, note string) (DTO, error) {
	svc := service.New(repository.NewPG(db))
	return svc.Create(ctx, userID, domain.CreateParams{
		SourceFragmentID: sourceFragmentID,
		TargetFragmentID: targetFragmentID,
		RelationType:     relationType,
		Note:             note,
	})
}

var _ http.Handler = (*Handler)(nil)
