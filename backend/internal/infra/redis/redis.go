package redis

import "xiguang/backend/internal/infra/config"

type Config struct {
	Addr string
}

func FromAppConfig(cfg config.Config) Config {
	return Config{Addr: cfg.RedisAddr}
}
