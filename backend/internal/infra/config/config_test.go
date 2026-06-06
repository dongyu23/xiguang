package config

import (
	"os"
	"testing"
)

func TestValidateAllowsDevelopmentDefaults(t *testing.T) {
	cfg := Config{
		Env:           "development",
		JWTSecret:     "dev_only_change_me_64_chars_minimum_for_real_deployments",
		AllowedOrigin: "*",
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("development defaults should be allowed: %v", err)
	}
}

func TestValidateRejectsProductionDefaults(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("DB_PASSWORD", "")
	cfg := Config{
		Env:           "production",
		JWTSecret:     "dev_only_change_me_64_chars_minimum_for_real_deployments",
		AllowedOrigin: "*",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected production defaults to be rejected")
	}
}

func TestValidateAcceptsProductionExplicitConfig(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://example")
	t.Setenv("DB_PASSWORD", "")
	cfg := Config{
		Env:           "production",
		JWTSecret:     "real-secret-that-is-not-the-development-default",
		AllowedOrigin: "https://example.com",
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected explicit production config to pass: %v", err)
	}
	_ = os.Getenv("DATABASE_URL")
}
