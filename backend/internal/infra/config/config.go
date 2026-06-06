package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	Env                 string
	Port                string
	JWTSecret           string
	AccessExpiry        time.Duration
	RefreshExpiry       time.Duration
	DatabaseURL         string
	RedisAddr           string
	MinIOEndpoint       string
	MinIOBucket         string
	AIProvider          string
	DeepSeekAPIKey      string
	DeepSeekBaseURL     string
	DeepSeekModel       string
	AIDailyQuotaPerUser int
	AllowedOrigin       string
}

func Load() Config {
	accessExpiry, _ := time.ParseDuration(env("JWT_ACCESS_EXPIRY", "15m"))
	refreshExpiry, _ := time.ParseDuration(env("JWT_REFRESH_EXPIRY", "720h"))
	quota, _ := strconv.Atoi(env("AI_DAILY_QUOTA_PER_USER", "50"))
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://" + env("DB_USER", "glimmer") + ":" + env("DB_PASSWORD", "glimmer_dev_password") +
			"@" + env("DB_HOST", "localhost") + ":" + env("DB_PORT", "5432") + "/" + env("DB_NAME", "glimmer") +
			"?sslmode=" + env("DB_SSLMODE", "disable")
	}
	return Config{
		Env:                 env("APP_ENV", "development"),
		Port:                env("APP_PORT", "8080"),
		JWTSecret:           env("JWT_SECRET", "dev_only_change_me_64_chars_minimum_for_real_deployments"),
		AccessExpiry:        accessExpiry,
		RefreshExpiry:       refreshExpiry,
		DatabaseURL:         dbURL,
		RedisAddr:           env("REDIS_HOST", "localhost") + ":" + env("REDIS_PORT", "6379"),
		MinIOEndpoint:       env("MINIO_ENDPOINT", "localhost:9000"),
		MinIOBucket:         env("MINIO_BUCKET", "glimmer-media"),
		AIProvider:          env("AI_PROVIDER", "deepseek"),
		DeepSeekAPIKey:      os.Getenv("AI_DEEPSEEK_API_KEY"),
		DeepSeekBaseURL:     env("AI_DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1"),
		DeepSeekModel:       env("AI_DEEPSEEK_MODEL", "deepseek-chat"),
		AIDailyQuotaPerUser: quota,
		AllowedOrigin:       env("ALLOWED_ORIGIN", "*"),
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
