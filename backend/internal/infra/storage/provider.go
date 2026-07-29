package storage

import (
	"context"
	"time"
)

type ObjectInfo struct {
	Size        int64
	ContentType string
}

type Provider interface {
	PresignedPutObject(ctx context.Context, objectKey, contentType string, ttl time.Duration) (string, error)
	PresignedGetObject(ctx context.Context, objectKey string, ttl time.Duration) (string, error)
	StatObject(ctx context.Context, objectKey string) (ObjectInfo, error)
	PutObject(ctx context.Context, objectKey, contentType string, data []byte) error
	DeleteObject(ctx context.Context, objectKey string) error
}
