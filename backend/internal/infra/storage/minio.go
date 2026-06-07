package storage

import (
	"bytes"
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

	// MinIO 可能还在启动，重试 bucket 检测
	var lastErr error
	for i := 0; i < 5; i++ {
		if i > 0 {
			time.Sleep(2 * time.Second)
		}
		exists, err := client.BucketExists(context.Background(), cfg.MinIOBucket)
		if err != nil {
			lastErr = err
			continue
		}
		if !exists {
			if err := client.MakeBucket(context.Background(), cfg.MinIOBucket, minio.MakeBucketOptions{}); err != nil {
				lastErr = err
				continue
			}
		}
		return &MinIOProvider{client: client, bucket: cfg.MinIOBucket}, nil
	}
	return nil, fmt.Errorf("minio bucket check after retries: %w", lastErr)
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

func (p *MinIOProvider) PutObject(ctx context.Context, objectKey, contentType string, data []byte) error {
	_, err := p.client.PutObject(ctx, p.bucket, objectKey, bytes.NewReader(data), int64(len(data)), minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

func (p *MinIOProvider) DeleteObject(ctx context.Context, objectKey string) error {
	return p.client.RemoveObject(ctx, p.bucket, objectKey, minio.RemoveObjectOptions{})
}
