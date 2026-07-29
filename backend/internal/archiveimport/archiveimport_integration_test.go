package archiveimport

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	billingservice "xiguang/backend/internal/billing/service"
	infraDB "xiguang/backend/internal/infra/db"
	"xiguang/backend/internal/infra/storage"
)

type archiveStorage struct {
	info    storage.ObjectInfo
	deleted []string
}

func (s *archiveStorage) PresignedPutObject(context.Context, string, string, time.Duration) (string, error) {
	return "", nil
}
func (s *archiveStorage) PresignedGetObject(context.Context, string, time.Duration) (string, error) {
	return "", nil
}
func (s *archiveStorage) StatObject(context.Context, string) (storage.ObjectInfo, error) {
	return s.info, nil
}
func (s *archiveStorage) PutObject(context.Context, string, string, []byte) error { return nil }
func (s *archiveStorage) DeleteObject(_ context.Context, key string) error {
	s.deleted = append(s.deleted, key)
	return nil
}

type archiveQuota struct {
	limit        int64
	reservedSize int64
	released     []string
}

func (q *archiveQuota) ReserveStorageFor(_ context.Context, _ int64, _ string, bytes int64, _ time.Duration) error {
	q.reservedSize = bytes
	if q.limit > 0 && bytes > q.limit {
		return billingservice.ErrStorageQuota
	}
	return nil
}
func (q *archiveQuota) ConsumeStorage(context.Context, int64, string) error { return nil }
func (q *archiveQuota) ReleaseStorage(_ context.Context, _ int64, key string) {
	q.released = append(q.released, key)
}

func archiveImportDB(t *testing.T) (*pgxpool.Pool, int64, string) {
	t.Helper()
	dsn := os.Getenv("BILLING_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("BILLING_TEST_DATABASE_URL is not configured")
	}
	pool, err := infraDB.Connect(t.Context(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	var userID int64
	if err = pool.QueryRow(t.Context(), `INSERT INTO users(username,password_hash,nickname) VALUES($1,'test','archive') RETURNING id`,
		fmt.Sprintf("archive_import_it_%d", time.Now().UnixNano())).Scan(&userID); err != nil {
		pool.Close()
		t.Fatal(err)
	}
	importID := uuid.NewString()
	if _, err = pool.Exec(t.Context(), `INSERT INTO archive_imports(id,user_id,manifest) VALUES($1,$2,'{"format":"xiguang-archive","version":1}')`, importID, userID); err != nil {
		pool.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, userID)
		pool.Close()
	})
	return pool, userID, importID
}

func TestPrepareMediaUsesStoredObjectSizeForQuota(t *testing.T) {
	pool, userID, importID := archiveImportDB(t)
	const hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	const key = "users/archive/actual-size.jpg"
	if _, err := pool.Exec(t.Context(), `INSERT INTO archive_import_media(import_id,sha256,object_key,mime_type,file_size)
		VALUES($1,$2,$3,'image/jpeg',1)`, importID, hash, key); err != nil {
		t.Fatal(err)
	}
	provider := &archiveStorage{info: storage.ObjectInfo{Size: 2 << 20, ContentType: "image/jpeg"}}
	quota := &archiveQuota{limit: 1 << 20}
	handler := &Handler{db: pool, provider: provider, quota: quota}

	_, err := handler.prepareMedia(t.Context(), userID, importID, commitRequest{
		Fragments: []fragmentInput{{MediaSHA: []string{hash}}},
	})
	if !errors.Is(err, billingservice.ErrStorageQuota) {
		t.Fatalf("prepareMedia() error = %v, want storage quota", err)
	}
	if quota.reservedSize != 2<<20 {
		t.Fatalf("reserved bytes = %d, want actual object size", quota.reservedSize)
	}
}

func TestPrepareMediaRejectsAndDeletesInvalidStoredObject(t *testing.T) {
	pool, userID, importID := archiveImportDB(t)
	const hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	const key = "users/archive/not-media.bin"
	if _, err := pool.Exec(t.Context(), `INSERT INTO archive_import_media(import_id,sha256,object_key,mime_type,file_size)
		VALUES($1,$2,$3,'image/jpeg',1)`, importID, hash, key); err != nil {
		t.Fatal(err)
	}
	provider := &archiveStorage{info: storage.ObjectInfo{Size: 128, ContentType: "application/octet-stream"}}
	quota := &archiveQuota{}
	handler := &Handler{db: pool, provider: provider, quota: quota}

	if _, err := handler.prepareMedia(t.Context(), userID, importID, commitRequest{
		Fragments: []fragmentInput{{MediaSHA: []string{hash}}},
	}); err == nil {
		t.Fatal("invalid stored object was accepted")
	}
	if len(provider.deleted) != 1 || provider.deleted[0] != key {
		t.Fatalf("deleted objects = %#v", provider.deleted)
	}
	if quota.reservedSize != 0 {
		t.Fatalf("invalid object reserved %d bytes", quota.reservedSize)
	}
}
