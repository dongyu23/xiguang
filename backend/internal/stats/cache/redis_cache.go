package cache

import "time"

type RedisCacheConfig struct {
	TTL time.Duration
}

func DefaultRedisCacheConfig() RedisCacheConfig {
	return RedisCacheConfig{TTL: 10 * time.Minute}
}
