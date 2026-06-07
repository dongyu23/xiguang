package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
	"xiguang/backend/internal/media/domain"
	"xiguang/backend/internal/media/repository"
)

var (
	ErrInvalidPresign = errors.New("invalid_presign")
	ErrInvalidConfirm = errors.New("invalid_confirm")
)

const presignTTL = 5 * time.Minute

type Service struct {
	repo     repository.Repository
	cfg      config.Config
	provider storage.Provider
}

func New(repo repository.Repository, cfg config.Config, provider storage.Provider) *Service {
	return &Service{repo: repo, cfg: cfg, provider: provider}
}

func (s *Service) Presign(userID int64, req domain.PresignRequest) (domain.PresignResponse, error) {
	if req.FileName == "" {
		return domain.PresignResponse{}, ErrInvalidPresign
	}
	ext := strings.ToLower(filepath.Ext(req.FileName))
	if ext == "" {
		ext = ".bin"
	}
	ts := time.Now().UTC().Format("20060102T150405")
	objectKey := fmt.Sprintf("users/%d/media/%s/%s_%d%s",
		userID, time.Now().UTC().Format("2006/01"), ts, time.Now().UnixNano()%100000, ext)

	resp := domain.PresignResponse{
		ObjectKey:        objectKey,
		ExpiresInSeconds: int(presignTTL.Seconds()),
	}

	if s.provider != nil {
		uploadURL, err := s.provider.PresignedPutObject(context.Background(), objectKey, req.ContentType, presignTTL)
		if err != nil {
			return domain.PresignResponse{}, fmt.Errorf("presign: %w", err)
		}
		resp.UploadURL = uploadURL
		resp.DirectUploadEnabled = true
	} else {
		resp.UploadURL = "/api/v1/media/direct-upload/" + objectKey
		resp.DirectUploadEnabled = false
	}

	return resp, nil
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

func (s *Service) Upload(ctx context.Context, userID, fragmentID int64, fileName string, data []byte) (domain.MediaFile, error) {
	const maxImageSize = 10 << 20  // 10MB
	const maxAudioSize = 50 << 20 // 50MB

	if len(data) == 0 || fileName == "" {
		return domain.MediaFile{}, fmt.Errorf("upload: empty file")
	}

	contentType := sniffMIME(fileName, data)
	maxSize := maxImageSize
	if strings.HasPrefix(contentType, "audio/") {
		maxSize = maxAudioSize
	}
	if len(data) > maxSize {
		return domain.MediaFile{}, fmt.Errorf("upload: file too large (%d > %d)", len(data), maxSize)
	}

	ext := strings.ToLower(filepath.Ext(fileName))
	if ext == "" {
		ext = ".bin"
	}
	ts := time.Now().UTC().Format("20060102T150405")
	objectKey := fmt.Sprintf("users/%d/media/%s/%s_%d%s",
		userID, time.Now().UTC().Format("2006/01"), ts, time.Now().UnixNano()%100000, ext)

	if s.provider != nil {
		if err := s.provider.PutObject(ctx, objectKey, contentType, data); err != nil {
			return domain.MediaFile{}, fmt.Errorf("upload: store: %w", err)
		}
	}

	return s.repo.Create(ctx, userID, domain.CreateMediaRequest{
		FragmentID: fragmentID,
		ObjectKey:  objectKey,
		FileName:   fileName,
		MimeType:   contentType,
		FileSize:   int64(len(data)),
	})
}

func sniffMIME(fileName string, data []byte) string {
	ct := "application/octet-stream"
	ext := strings.ToLower(filepath.Ext(fileName))
	switch ext {
	case ".jpg", ".jpeg":
		ct = "image/jpeg"
	case ".png":
		ct = "image/png"
	case ".heic", ".heif":
		ct = "image/heic"
	case ".webp":
		ct = "image/webp"
	case ".m4a":
		ct = "audio/mp4"
	case ".aac":
		ct = "audio/aac"
	case ".mp3":
		ct = "audio/mpeg"
	case ".wav":
		ct = "audio/wav"
	}
	// If the extension didn't tell us, try http.DetectContentType.
	if ct == "application/octet-stream" && len(data) > 0 {
		ct = http.DetectContentType(data)
	}
	return ct
}

func (s *Service) Get(ctx context.Context, userID, mediaID int64) (domain.MediaFile, error) {
	return s.repo.Get(ctx, userID, mediaID)
}

func (s *Service) Delete(ctx context.Context, userID, mediaID int64) (bool, error) {
	return s.repo.Delete(ctx, userID, mediaID)
}
