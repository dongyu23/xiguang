package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEnvSupportsFileValues(t *testing.T) {
	path := filepath.Join(t.TempDir(), "payment_channels")
	if err := os.WriteFile(path, []byte("apple,wechat\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PAYMENT_CHANNELS", "alipay")
	t.Setenv("PAYMENT_CHANNELS_FILE", path)
	if got := env("PAYMENT_CHANNELS", ""); got != "apple,wechat" {
		t.Fatalf("env file value = %q", got)
	}
}

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
	t.Setenv("MINIO_ACCESS_KEY", "prod-minio-access-key")
	t.Setenv("MINIO_SECRET_KEY", "prod-minio-secret-key")
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

func TestValidateRejectsIncompletePaymentChannel(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://example")
	t.Setenv("MINIO_ACCESS_KEY", "key")
	t.Setenv("MINIO_SECRET_KEY", "secret")
	cfg := Config{Env: "production", JWTSecret: "strong-production-secret", AllowedOrigin: "https://example.com", PaymentEnabled: true, PaymentEnvironment: "production", PaymentPublicBaseURL: "https://example.com", PaymentEncryptionKey: "01234567890123456789012345678901", PaymentChannels: []string{"apple"}}
	if err := cfg.Validate(); err == nil {
		t.Fatal("incomplete Apple credentials must be rejected")
	}
}

func TestValidateRejectsIncompletePaymentsInDevelopment(t *testing.T) {
	cfg := Config{
		Env:                  "development",
		PaymentEnabled:       true,
		PaymentEnvironment:   "sandbox",
		PaymentPublicBaseURL: "https://example.com",
		PaymentEncryptionKey: "01234567890123456789012345678901",
		PaymentChannels:      []string{"apple"},
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("enabled sandbox payments must still require channel credentials")
	}
}

func TestValidateRejectsSandboxPaymentsInProductionApp(t *testing.T) {
	cfg := Config{
		Env:                  "production",
		PaymentEnabled:       true,
		PaymentEnvironment:   "sandbox",
		PaymentPublicBaseURL: "https://example.com",
		PaymentEncryptionKey: "01234567890123456789012345678901",
		PaymentChannels:      []string{"apple"},
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("production app must reject sandbox payment mode")
	}
}

func TestValidateRejectsAlipaySandboxGatewayInProduction(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://example")
	t.Setenv("MINIO_ACCESS_KEY", "key")
	t.Setenv("MINIO_SECRET_KEY", "secret")
	cfg := Config{
		Env: "production", JWTSecret: "strong-production-secret", AllowedOrigin: "https://example.com",
		PaymentEnabled: true, PaymentEnvironment: "production", PaymentPublicBaseURL: "https://example.com",
		PaymentEncryptionKey: "01234567890123456789012345678901", PaymentChannels: []string{"alipay"},
		AlipayAppID: "app", AlipayAppPrivateKey: "private", AlipayAppPublicCert: "app-cert", AlipayPublicCert: "cert", AlipayRootCert: "root",
		AlipayProductCode: "CYCLE_PAY_AUTH_P", AlipayGateway: "https://openapi-sandbox.dl.alipaydev.com/gateway.do",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("production Alipay sandbox gateway must be rejected")
	}
}
