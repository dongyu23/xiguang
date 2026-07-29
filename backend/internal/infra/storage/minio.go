package storage

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"xiguang/backend/internal/infra/config"
)

// MinIOProvider implements Provider using the MinIO Go client.
type MinIOProvider struct {
	client        *minio.Client
	presignClient *minio.Client
	bucket        string
}

func NewMinIOProvider(cfg config.Config) (*MinIOProvider, error) {
	useSSL := cfg.MinIOEndpoint != "minio:9000"
	transport := http.DefaultTransport.(*http.Transport).Clone()
	// The app and MinIO share a private Docker network. Host proxy variables
	// must never intercept service-to-service traffic such as `minio:9000`.
	if cfg.MinIOEndpoint == "minio:9000" {
		transport.Proxy = nil
	}
	client, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:     credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure:    useSSL,
		Transport: transport,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}
	presignClient := client
	if strings.TrimSpace(cfg.MinIOPublicEndpoint) != "" {
		endpoint, secure, parseErr := parseEndpoint(cfg.MinIOPublicEndpoint)
		if parseErr != nil {
			return nil, fmt.Errorf("minio public endpoint: %w", parseErr)
		}
		presignClient, err = minio.New(endpoint, &minio.Options{
			Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
			Secure: secure,
		})
		if err != nil {
			return nil, fmt.Errorf("minio public client: %w", err)
		}
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
		// Clients only receive short-lived signed URLs. Remove any anonymous
		// policy left on an existing bucket before accepting traffic.
		policy, policyErr := client.GetBucketPolicy(context.Background(), cfg.MinIOBucket)
		if policyErr != nil {
			lastErr = policyErr
			continue
		}
		if policy != "" {
			if err := client.SetBucketPolicy(context.Background(), cfg.MinIOBucket, ""); err != nil {
				lastErr = err
				continue
			}
		}
		return &MinIOProvider{client: client, presignClient: presignClient, bucket: cfg.MinIOBucket}, nil
	}
	return nil, fmt.Errorf("minio bucket check after retries: %w", lastErr)
}

func (p *MinIOProvider) PresignedPutObject(ctx context.Context, objectKey, contentType string, ttl time.Duration) (string, error) {
	url, err := p.presignClient.PresignedPutObject(ctx, p.bucket, objectKey, ttl)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (p *MinIOProvider) PresignedGetObject(ctx context.Context, objectKey string, ttl time.Duration) (string, error) {
	url, err := p.presignClient.PresignedGetObject(ctx, p.bucket, objectKey, ttl, nil)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

func (p *MinIOProvider) StatObject(ctx context.Context, objectKey string) (ObjectInfo, error) {
	info, err := p.client.StatObject(ctx, p.bucket, objectKey, minio.StatObjectOptions{})
	if err != nil {
		return ObjectInfo{}, err
	}
	return ObjectInfo{Size: info.Size, ContentType: info.ContentType}, nil
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

func parseEndpoint(value string) (string, bool, error) {
	if !strings.Contains(value, "://") {
		return strings.TrimRight(value, "/"), false, nil
	}
	parsed, err := url.Parse(value)
	if err != nil || parsed.Host == "" {
		return "", false, fmt.Errorf("invalid endpoint")
	}
	if parsed.Path != "" && parsed.Path != "/" {
		return "", false, fmt.Errorf("endpoint must not include a path")
	}
	return parsed.Host, parsed.Scheme == "https", nil
}
