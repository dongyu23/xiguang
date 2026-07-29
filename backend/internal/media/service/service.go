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

	billingrepo "xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
	"xiguang/backend/internal/media/domain"
	"xiguang/backend/internal/media/repository"
)

var (
	ErrInvalidPresign = errors.New("invalid_presign")
	ErrInvalidConfirm = errors.New("invalid_confirm")
	ErrInvalidExport  = errors.New("invalid_export")
	ErrMediaOwnership = errors.New("media_ownership")
)

const presignTTL = 5 * time.Minute
const exportTTL = 10 * time.Minute

const (
	maxImageSize = 10 << 20
	maxAudioSize = 50 << 20
)

var ErrQuotaExceeded = billingrepo.ErrStorageQuota

type ExportURL struct {
	ObjectKey        string `json:"object_key"`
	DownloadURL      string `json:"download_url"`
	MimeType         string `json:"mime_type"`
	FileSize         int64  `json:"file_size"`
	ExpiresInSeconds int    `json:"expires_in_seconds"`
}

type Service struct {
	repo     repository.Repository
	cfg      config.Config
	provider storage.Provider
	quota    QuotaService
}

type QuotaService interface {
	ReserveStorage(ctx context.Context, userID int64, objectKey string, bytes int64) error
	ConsumeStorage(ctx context.Context, userID int64, objectKey string) error
	ReleaseStorage(ctx context.Context, userID int64, objectKey string)
}

func New(repo repository.Repository, cfg config.Config, provider storage.Provider, quotas ...QuotaService) *Service {
	var quota QuotaService
	if len(quotas) > 0 {
		quota = quotas[0]
	}
	return &Service{repo: repo, cfg: cfg, provider: provider, quota: quota}
}

func (s *Service) Presign(ctx context.Context, userID int64, req domain.PresignRequest) (domain.PresignResponse, error) {
	if req.FileName == "" || !validMediaSize(req.ContentType, req.FileSize) || s.provider == nil {
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
	if s.quota != nil {
		if err := s.quota.ReserveStorage(ctx, userID, objectKey, req.FileSize); err != nil {
			return domain.PresignResponse{}, err
		}
	}

	uploadURL, err := s.provider.PresignedPutObject(ctx, objectKey, req.ContentType, presignTTL)
	if err != nil {
		if s.quota != nil {
			s.quota.ReleaseStorage(ctx, userID, objectKey)
		}
		return domain.PresignResponse{}, fmt.Errorf("presign: %w", err)
	}
	resp.UploadURL = uploadURL
	resp.DirectUploadEnabled = true

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
	if existing, err := s.repo.GetByObjectKey(ctx, userID, req.ObjectKey); err == nil {
		return existing, nil
	}
	if s.provider == nil {
		return domain.MediaFile{}, ErrInvalidConfirm
	}
	info, err := s.provider.StatObject(ctx, req.ObjectKey)
	if err != nil || !validMediaSize(info.ContentType, info.Size) {
		return domain.MediaFile{}, ErrInvalidConfirm
	}
	req.FileSize = info.Size
	req.MimeType = info.ContentType
	if s.quota != nil {
		if err := s.quota.ReserveStorage(ctx, userID, req.ObjectKey, info.Size); err != nil {
			return domain.MediaFile{}, err
		}
	}
	item, err := s.repo.Confirm(ctx, userID, req)
	if err != nil && s.quota != nil {
		s.quota.ReleaseStorage(ctx, userID, req.ObjectKey)
		return item, err
	}
	if s.quota != nil {
		if err = s.quota.ConsumeStorage(ctx, userID, req.ObjectKey); err != nil {
			return domain.MediaFile{}, err
		}
	}
	return item, err
}

func (s *Service) Upload(ctx context.Context, userID, fragmentID int64, fileName string, data []byte) (domain.MediaFile, error) {
	if len(data) == 0 || fileName == "" {
		return domain.MediaFile{}, fmt.Errorf("upload: empty file")
	}

	contentType := sniffMIME(fileName, data)
	if !validMediaSize(contentType, int64(len(data))) {
		return domain.MediaFile{}, fmt.Errorf("upload: unsupported or oversized media")
	}

	ext := strings.ToLower(filepath.Ext(fileName))
	if ext == "" {
		ext = ".bin"
	}
	ts := time.Now().UTC().Format("20060102T150405")
	objectKey := fmt.Sprintf("users/%d/media/%s/%s_%d%s",
		userID, time.Now().UTC().Format("2006/01"), ts, time.Now().UnixNano()%100000, ext)
	if s.quota != nil {
		if err := s.quota.ReserveStorage(ctx, userID, objectKey, int64(len(data))); err != nil {
			return domain.MediaFile{}, err
		}
	}

	if s.provider != nil {
		if err := s.provider.PutObject(ctx, objectKey, contentType, data); err != nil {
			if s.quota != nil {
				s.quota.ReleaseStorage(ctx, userID, objectKey)
			}
			return domain.MediaFile{}, fmt.Errorf("upload: store: %w", err)
		}
	}

	item, err := s.repo.Create(ctx, userID, domain.CreateMediaRequest{
		FragmentID: fragmentID,
		ObjectKey:  objectKey,
		FileName:   fileName,
		MimeType:   contentType,
		FileSize:   int64(len(data)),
	})
	if err != nil {
		if s.quota != nil {
			s.quota.ReleaseStorage(ctx, userID, objectKey)
		}
		return item, err
	}
	if s.quota != nil {
		if err = s.quota.ConsumeStorage(ctx, userID, objectKey); err != nil {
			return domain.MediaFile{}, err
		}
	}
	return item, nil
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
	item, err := s.repo.Get(ctx, userID, mediaID)
	if err != nil {
		return item, err
	}
	if s.provider != nil {
		signed, signErr := s.provider.PresignedGetObject(ctx, item.ObjectKey, presignTTL)
		if signErr != nil {
			return item, signErr
		}
		item.FileURL = signed
	}
	return item, nil
}

func validMediaSize(contentType string, size int64) bool {
	if size <= 0 {
		return false
	}
	contentType = strings.ToLower(strings.TrimSpace(strings.Split(contentType, ";")[0]))
	switch {
	case strings.HasPrefix(contentType, "image/"):
		return size <= maxImageSize
	case strings.HasPrefix(contentType, "audio/"):
		return size <= maxAudioSize
	default:
		return false
	}
}

func (s *Service) GetByObjectKey(ctx context.Context, userID int64, objectKey string) (domain.MediaFile, error) {
	prefix := "users/" + strconv.FormatInt(userID, 10) + "/media/"
	if !strings.HasPrefix(objectKey, prefix) || strings.Contains(objectKey, "..") || strings.Contains(objectKey, "\\") {
		return domain.MediaFile{}, ErrMediaOwnership
	}
	item, err := s.repo.GetByObjectKey(ctx, userID, objectKey)
	if err != nil {
		return item, err
	}
	if s.provider != nil {
		signed, signErr := s.provider.PresignedGetObject(ctx, item.ObjectKey, presignTTL)
		if signErr != nil {
			return item, signErr
		}
		item.FileURL = signed
	}
	return item, nil
}

func (s *Service) Delete(ctx context.Context, userID, mediaID int64) (bool, error) {
	return s.repo.Delete(ctx, userID, mediaID)
}

func (s *Service) ExportURLs(ctx context.Context, userID int64, objectKeys []string) ([]ExportURL, error) {
	if len(objectKeys) == 0 || len(objectKeys) > 100 {
		return nil, ErrInvalidExport
	}
	prefix := "users/" + strconv.FormatInt(userID, 10) + "/media/"
	seen := make(map[string]struct{}, len(objectKeys))
	for _, key := range objectKeys {
		if !strings.HasPrefix(key, prefix) || strings.Contains(key, "..") || strings.Contains(key, "\\") {
			return nil, ErrMediaOwnership
		}
		seen[key] = struct{}{}
	}
	owned, err := s.repo.FindByObjectKeys(ctx, userID, objectKeys)
	if err != nil {
		return nil, err
	}
	if len(owned) != len(seen) {
		return nil, ErrMediaOwnership
	}
	result := make([]ExportURL, 0, len(owned))
	for _, item := range owned {
		url := item.FileURL
		if s.provider != nil {
			url, err = s.provider.PresignedGetObject(ctx, item.ObjectKey, exportTTL)
			if err != nil {
				return nil, fmt.Errorf("presign export: %w", err)
			}
		}
		result = append(result, ExportURL{
			ObjectKey: item.ObjectKey, DownloadURL: url, MimeType: item.MimeType,
			FileSize: item.FileSize, ExpiresInSeconds: int(exportTTL.Seconds()),
		})
	}
	return result, nil
}
