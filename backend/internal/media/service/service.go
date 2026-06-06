package service

import (
	"context"
	"errors"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/media/domain"
	"xiguang/backend/internal/media/repository"
)

var (
	ErrInvalidPresign = errors.New("invalid_presign")
	ErrInvalidConfirm = errors.New("invalid_confirm")
)

type Service struct {
	repo repository.Repository
	cfg  config.Config
}

func New(repo repository.Repository, cfg config.Config) *Service {
	return &Service{repo: repo, cfg: cfg}
}

func (s *Service) Presign(userID int64, req domain.PresignRequest) (domain.PresignResponse, error) {
	if req.FileName == "" {
		return domain.PresignResponse{}, ErrInvalidPresign
	}
	ext := strings.ToLower(filepath.Ext(req.FileName))
	if ext == "" {
		ext = ".bin"
	}
	objectKey := "users/" + strconv.FormatInt(userID, 10) + "/media/" + time.Now().Format("2006/01/02150405") + ext
	return domain.PresignResponse{
		UploadURL:           "/media-upload-placeholder/" + objectKey,
		ObjectKey:           objectKey,
		ExpiresInSeconds:    300,
		DirectUploadEnabled: false,
	}, nil
}

func (s *Service) Confirm(ctx context.Context, userID int64, req domain.ConfirmRequest) (domain.MediaFile, error) {
	prefix := "users/" + strconv.FormatInt(userID, 10) + "/media/"
	if req.ObjectKey == "" ||
		req.FragmentID <= 0 ||
		!strings.HasPrefix(req.ObjectKey, prefix) ||
		strings.HasPrefix(req.ObjectKey, "data:") ||
		strings.HasPrefix(req.ObjectKey, "file:") ||
		strings.HasPrefix(req.ObjectKey, "/") ||
		strings.Contains(req.ObjectKey, "\\") ||
		strings.Contains(req.ObjectKey, "../") {
		return domain.MediaFile{}, ErrInvalidConfirm
	}
	return s.repo.Confirm(ctx, userID, req)
}

func (s *Service) Get(ctx context.Context, userID, mediaID int64) (domain.MediaFile, error) {
	return s.repo.Get(ctx, userID, mediaID)
}

func (s *Service) Delete(ctx context.Context, userID, mediaID int64) (bool, error) {
	return s.repo.Delete(ctx, userID, mediaID)
}
