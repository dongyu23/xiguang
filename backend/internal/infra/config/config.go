package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Env                    string
	Port                   string
	JWTSecret              string
	AccessExpiry           time.Duration
	RefreshExpiry          time.Duration
	DatabaseURL            string
	RedisAddr              string
	MinIOEndpoint          string
	MinIOBucket            string
	MinIOAccessKey         string
	MinIOSecretKey         string
	AIProvider             string
	DeepSeekAPIKey         string
	DeepSeekBaseURL        string
	DeepSeekModel          string
	AIDailyQuotaPerUser    int
	ASRProvider            string
	TencentASRAppID        string
	TencentASRSecretID     string
	TencentASRSecretKey    string
	TencentASRRegion       string
	TencentASREndpoint     string
	TencentASREngine       string
	TencentASRRealtimeHost string
	AllowedOrigin          string
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
	cfg := Config{
		Env:                    env("APP_ENV", "development"),
		Port:                   env("APP_PORT", "8080"),
		JWTSecret:              env("JWT_SECRET", "dev_only_change_me_64_chars_minimum_for_real_deployments"),
		AccessExpiry:           accessExpiry,
		RefreshExpiry:          refreshExpiry,
		DatabaseURL:            dbURL,
		RedisAddr:              env("REDIS_HOST", "localhost") + ":" + env("REDIS_PORT", "6379"),
		MinIOEndpoint:          env("MINIO_ENDPOINT", "localhost:9000"),
		MinIOBucket:            env("MINIO_BUCKET", "glimmer-media"),
		MinIOAccessKey:         os.Getenv("MINIO_ACCESS_KEY"),
		MinIOSecretKey:         os.Getenv("MINIO_SECRET_KEY"),
		AIProvider:             env("AI_PROVIDER", "deepseek"),
		DeepSeekAPIKey:         os.Getenv("AI_DEEPSEEK_API_KEY"),
		DeepSeekBaseURL:        env("AI_DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1"),
		DeepSeekModel:          env("AI_DEEPSEEK_MODEL", "deepseek-chat"),
		AIDailyQuotaPerUser:    quota,
		ASRProvider:            env("ASR_PROVIDER", "tencent"),
		TencentASRAppID:        os.Getenv("TENCENT_ASR_APP_ID"),
		TencentASRSecretID:     os.Getenv("TENCENT_ASR_SECRET_ID"),
		TencentASRSecretKey:    os.Getenv("TENCENT_ASR_SECRET_KEY"),
		TencentASRRegion:       env("TENCENT_ASR_REGION", "ap-shanghai"),
		TencentASREndpoint:     env("TENCENT_ASR_ENDPOINT", "asr.tencentcloudapi.com"),
		TencentASREngine:       env("TENCENT_ASR_ENGINE_MODEL_TYPE", "16k_zh"),
		TencentASRRealtimeHost: env("TENCENT_ASR_REALTIME_HOST", "asr.cloud.tencent.com"),
		AllowedOrigin:          env("ALLOWED_ORIGIN", "*"),
	}
	if err := cfg.Validate(); err != nil {
		panic(err)
	}
	return cfg
}

func (c Config) Validate() error {
	if c.Env == "development" || c.Env == "dev" || c.Env == "test" {
		return nil
	}
	if c.JWTSecret == "" || c.JWTSecret == "dev_only_change_me_64_chars_minimum_for_real_deployments" {
		return fmt.Errorf("JWT_SECRET must be configured outside development")
	}
	if c.AllowedOrigin == "" || c.AllowedOrigin == "*" {
		return fmt.Errorf("ALLOWED_ORIGIN must be explicit outside development")
	}
	if os.Getenv("DATABASE_URL") == "" && os.Getenv("DB_PASSWORD") == "" {
		return fmt.Errorf("DB_PASSWORD or DATABASE_URL must be configured outside development")
	}
	if os.Getenv("DB_PASSWORD") == "glimmer_dev_password" {
		return fmt.Errorf("default DB_PASSWORD is not allowed outside development")
	}
	if os.Getenv("MINIO_ACCESS_KEY") == "" || os.Getenv("MINIO_SECRET_KEY") == "" {
		return fmt.Errorf("MINIO_ACCESS_KEY and MINIO_SECRET_KEY must be configured outside development")
	}
	return nil
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
