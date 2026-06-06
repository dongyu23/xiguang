package storage

import "xiguang/backend/internal/infra/config"

type MinIOConfig struct {
	Endpoint string
	Bucket   string
}

func MinIOFromAppConfig(cfg config.Config) MinIOConfig {
	return MinIOConfig{Endpoint: cfg.MinIOEndpoint, Bucket: cfg.MinIOBucket}
}
