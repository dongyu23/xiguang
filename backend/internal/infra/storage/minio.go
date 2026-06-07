package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"xiguang/backend/internal/infra/config"
)

// MinIOProvider implements Provider using the MinIO Go client.
type MinIOProvider struct {
	client *minio.Client
	bucket string
}

func NewMinIOProvider(cfg config.Config) (*MinIOProvider, error) {
	useSSL := cfg.MinIOEndpoint != "minio:9000"
	client, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}
	exists, err := client.BucketExists(context.Background(), cfg.MinIOBucket)
	if err != nil {
		return nil, fmt.Errorf("minio bucket check: %w", err)
	}
	if !exists {
		if err := client.MakeBucket(context.Background(), cfg.MinIOBucket, minio.MakeBucketOptions{}); err != nil {
			return nil, fmt.Errorf("minio create bucket: %w", err)
		}
	}
	return &MinIOProvider{client: client, bucket: cfg.MinIOBucket}, nil
}

func (p *MinIOProvider) PresignedPutObject(ctx context.Context, objectKey, contentType string, ttl time.Duration) (string, error) {
	url, err := p.client.PresignedPutObject(ctx, p.bucket, objectKey, ttl)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (p *MinIOProvider) PresignedGetObject(ctx context.Context, objectKey string, ttl time.Duration) (string, error) {
	url, err := p.client.PresignedGetObject(ctx, p.bucket, objectKey, ttl, nil)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (p *MinIOProvider) DeleteObject(ctx context.Context, objectKey string) error {
	return p.client.RemoveObject(ctx, p.bucket, objectKey, minio.RemoveObjectOptions{})
}
