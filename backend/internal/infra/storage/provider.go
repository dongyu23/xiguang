package storage

import (
	"context"
	"time"
)

type Provider interface {
	PresignedPutObject(ctx context.Context, objectKey, contentType string, ttl time.Duration) (string, error)
	PresignedGetObject(ctx context.Context, objectKey string, ttl time.Duration) (string, error)
	PutObject(ctx context.Context, objectKey, contentType string, data []byte) error
	DeleteObject(ctx context.Context, objectKey string) error
}
