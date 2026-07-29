package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"

	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/infra/storage"
	"xiguang/backend/internal/media/domain"
)

type fakeMediaRepo struct {
	confirmed *domain.ConfirmRequest
}

func (f *fakeMediaRepo) Confirm(_ context.Context, _ int64, req domain.ConfirmRequest) (domain.MediaFile, error) {
	f.confirmed = &req
	return domain.MediaFile{ObjectKey: req.ObjectKey, MimeType: req.MimeType, FileSize: req.FileSize}, nil
}

func (f *fakeMediaRepo) Create(context.Context, int64, domain.CreateMediaRequest) (domain.MediaFile, error) {
	return domain.MediaFile{}, nil
}

func (f *fakeMediaRepo) Get(context.Context, int64, int64) (domain.MediaFile, error) {
	return domain.MediaFile{}, pgx.ErrNoRows
}

func (f *fakeMediaRepo) GetByObjectKey(context.Context, int64, string) (domain.MediaFile, error) {
	return domain.MediaFile{}, pgx.ErrNoRows
}

func (f *fakeMediaRepo) FindByObjectKeys(context.Context, int64, []string) ([]domain.MediaFile, error) {
	return nil, nil
}

func (f *fakeMediaRepo) Delete(context.Context, int64, int64) (bool, error) {
	return false, nil
}

type fakeStorageProvider struct {
	info storage.ObjectInfo
}

func (f *fakeStorageProvider) PresignedPutObject(context.Context, string, string, time.Duration) (string, error) {
	return "https://upload.example.test", nil
}

func (f *fakeStorageProvider) PresignedGetObject(context.Context, string, time.Duration) (string, error) {
	return "https://download.example.test", nil
}

func (f *fakeStorageProvider) StatObject(context.Context, string) (storage.ObjectInfo, error) {
	return f.info, nil
}

func (f *fakeStorageProvider) PutObject(context.Context, string, string, []byte) error { return nil }
func (f *fakeStorageProvider) DeleteObject(context.Context, string) error              { return nil }

type fakeQuota struct {
	max          int64
	reservedSize int64
	consumed     bool
}

func (f *fakeQuota) ReserveStorage(_ context.Context, _ int64, _ string, bytes int64) error {
	f.reservedSize = bytes
	if f.max > 0 && bytes > f.max {
		return ErrQuotaExceeded
	}
	return nil
}

func (f *fakeQuota) ConsumeStorage(context.Context, int64, string) error {
	f.consumed = true
	return nil
}

func (f *fakeQuota) ReleaseStorage(context.Context, int64, string) {}

func TestConfirmUsesStoredObjectSizeForQuota(t *testing.T) {
	repo := &fakeMediaRepo{}
	provider := &fakeStorageProvider{info: storage.ObjectInfo{Size: 2 << 20, ContentType: "image/jpeg"}}
	quota := &fakeQuota{max: 1 << 20}
	svc := New(repo, config.Config{}, provider, quota)

	_, err := svc.Confirm(context.Background(), 7, domain.ConfirmRequest{
		FragmentID: 1,
		ObjectKey:  "users/7/media/2026/07/photo.jpg",
		FileName:   "photo.jpg",
		MimeType:   "image/jpeg",
		FileSize:   1,
	})
	if !errors.Is(err, ErrQuotaExceeded) {
		t.Fatalf("Confirm() error = %v, want quota exceeded", err)
	}
	if quota.reservedSize != 2<<20 {
		t.Fatalf("reserved bytes = %d, want actual object size", quota.reservedSize)
	}
	if repo.confirmed != nil {
		t.Fatal("media metadata was written after actual-size quota rejection")
	}
}

func TestConfirmPersistsStoredObjectMetadata(t *testing.T) {
	repo := &fakeMediaRepo{}
	provider := &fakeStorageProvider{info: storage.ObjectInfo{Size: 4096, ContentType: "audio/mp4"}}
	quota := &fakeQuota{}
	svc := New(repo, config.Config{}, provider, quota)

	item, err := svc.Confirm(context.Background(), 7, domain.ConfirmRequest{
		FragmentID: 1,
		ObjectKey:  "users/7/media/2026/07/voice.m4a",
		FileName:   "voice.m4a",
		MimeType:   "image/png",
		FileSize:   1,
	})
	if err != nil {
		t.Fatalf("Confirm() error = %v", err)
	}
	if repo.confirmed == nil || repo.confirmed.FileSize != 4096 || repo.confirmed.MimeType != "audio/mp4" {
		t.Fatalf("persisted metadata = %#v, want object-store metadata", repo.confirmed)
	}
	if item.FileSize != 4096 || item.MimeType != "audio/mp4" || !quota.consumed {
		t.Fatalf("result = %#v, consumed = %v", item, quota.consumed)
	}
}

func TestPresignRejectsUnsupportedOrOversizedMedia(t *testing.T) {
	tests := []domain.PresignRequest{
		{FileName: "payload.bin", ContentType: "application/octet-stream", FileSize: 10},
		{FileName: "photo.jpg", ContentType: "image/jpeg", FileSize: maxImageSize + 1},
		{FileName: "voice.m4a", ContentType: "audio/mp4", FileSize: maxAudioSize + 1},
	}
	for _, req := range tests {
		svc := New(&fakeMediaRepo{}, config.Config{}, &fakeStorageProvider{}, &fakeQuota{})
		if _, err := svc.Presign(context.Background(), 7, req); !errors.Is(err, ErrInvalidPresign) {
			t.Fatalf("Presign(%#v) error = %v, want invalid presign", req, err)
		}
	}
}
