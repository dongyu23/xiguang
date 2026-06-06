package storage

import (
	"context"

	"xiguang/backend/internal/media/domain"
)

type Uploader interface {
	PresignUpload(ctx context.Context, userID int64, req domain.PresignRequest) (domain.PresignResponse, error)
	ConfirmUpload(ctx context.Context, userID int64, req domain.ConfirmRequest) (domain.MediaFile, error)
}
