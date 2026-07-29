package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
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
	MinIOPublicEndpoint    string
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
	PaymentEnabled         bool
	PaymentEnvironment     string
	PaymentChannels        []string
	PaymentPublicBaseURL   string
	PaymentEncryptionKey   string
	AppleBundleID          string
	AppleAppID             string
	AppleIssuerID          string
	AppleKeyID             string
	ApplePrivateKey        string
	WeChatPayAppID         string
	WeChatPayMerchantID    string
	WeChatPayCertSerial    string
	WeChatPayPrivateKey    string
	WeChatPayAPIV3Key      string
	WeChatPayPlanID        string
	WeChatPayAPIBase       string
	WeChatPayContractPath  string
	WeChatPayChargePath    string
	WeChatPayQueryPath     string
	WeChatPayCancelPath    string
	AlipayAppID            string
	AlipayAppPrivateKey    string
	AlipayAppPublicCert    string
	AlipayPublicCert       string
	AlipayRootCert         string
	AlipayProductCode      string
	AlipaySignScene        string
	AlipayGateway          string

	// 在线更新：APK 静态目录绝对路径，以及客户端可访问的下载基地址。
	// 静态目录用于发版时校验文件已上传；下载基地址形如 https://host/media/app。
	ReleaseStaticDir    string
	ReleaseDownloadBase string
}

func Load() Config {
	accessExpiry, _ := time.ParseDuration(env("JWT_ACCESS_EXPIRY", "15m"))
	refreshExpiry, _ := time.ParseDuration(env("JWT_REFRESH_EXPIRY", "720h"))
	quota, _ := strconv.Atoi(env("AI_DAILY_QUOTA_PER_USER", "50"))
	paymentEnabled, _ := strconv.ParseBool(env("PAYMENT_ENABLED", "false"))
	paymentEnvironment := env("PAYMENT_ENV", "sandbox")
	alipayGatewayDefault := "https://openapi.alipay.com/gateway.do"
	if paymentEnvironment == "sandbox" {
		alipayGatewayDefault = "https://openapi-sandbox.dl.alipaydev.com/gateway.do"
	}
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
		MinIOPublicEndpoint:    os.Getenv("MINIO_PUBLIC_ENDPOINT"),
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
		PaymentEnabled:         paymentEnabled,
		PaymentEnvironment:     paymentEnvironment,
		PaymentChannels:        splitCSV(env("PAYMENT_CHANNELS", "")),
		PaymentPublicBaseURL:   strings.TrimRight(env("PAYMENT_PUBLIC_BASE_URL", ""), "/"),
		PaymentEncryptionKey:   secret("PAYMENT_DATA_ENCRYPTION_KEY"),
		AppleBundleID:          secret("APPLE_BUNDLE_ID"),
		AppleAppID:             secret("APPLE_APP_ID"),
		AppleIssuerID:          secret("APPLE_ISSUER_ID"),
		AppleKeyID:             secret("APPLE_KEY_ID"),
		ApplePrivateKey:        secret("APPLE_PRIVATE_KEY_BASE64"),
		WeChatPayAppID:         secret("WECHAT_PAY_APP_ID"),
		WeChatPayMerchantID:    secret("WECHAT_PAY_MCH_ID"),
		WeChatPayCertSerial:    secret("WECHAT_PAY_CERT_SERIAL"),
		WeChatPayPrivateKey:    secret("WECHAT_PAY_PRIVATE_KEY_BASE64"),
		WeChatPayAPIV3Key:      secret("WECHAT_PAY_API_V3_KEY"),
		WeChatPayPlanID:        secret("WECHAT_PAY_PLAN_ID"),
		WeChatPayAPIBase:       strings.TrimRight(env("WECHAT_PAY_API_BASE", "https://api.mch.weixin.qq.com"), "/"),
		WeChatPayContractPath:  env("WECHAT_PAY_CONTRACT_PATH", "/v3/papay/contracts/app-pre-entrust-sign"),
		WeChatPayChargePath:    env("WECHAT_PAY_CHARGE_PATH", "/v3/papay/transactions"),
		WeChatPayQueryPath:     env("WECHAT_PAY_QUERY_PATH", "/v3/papay/transactions/out-trade-no/{out_trade_no}"),
		WeChatPayCancelPath:    env("WECHAT_PAY_CANCEL_PATH", "/v3/papay/contracts/{contract_id}/terminate"),
		AlipayAppID:            secret("ALIPAY_APP_ID"),
		AlipayAppPrivateKey:    secret("ALIPAY_APP_PRIVATE_KEY_BASE64"),
		AlipayAppPublicCert:    secret("ALIPAY_APP_PUBLIC_CERT_BASE64"),
		AlipayPublicCert:       secret("ALIPAY_PUBLIC_CERT_BASE64"),
		AlipayRootCert:         secret("ALIPAY_ROOT_CERT_BASE64"),
		AlipayProductCode:      secret("ALIPAY_PERSONAL_PRODUCT_CODE"),
		AlipaySignScene:        env("ALIPAY_SIGN_SCENE", "INDUSTRY|DEFAULT"),
		AlipayGateway:          env("ALIPAY_GATEWAY", alipayGatewayDefault),
		ReleaseStaticDir:       env("RELEASE_STATIC_DIR", ""),
		ReleaseDownloadBase:    env("RELEASE_DOWNLOAD_BASE", "/media/app"),
	}
	if err := cfg.Validate(); err != nil {
		panic(err)
	}
	return cfg
}

func (c Config) Validate() error {
	if err := c.validatePayments(); err != nil {
		return err
	}
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

func (c Config) validatePayments() error {
	if !c.PaymentEnabled {
		return nil
	}
	if len(c.PaymentChannels) == 0 {
		return fmt.Errorf("PAYMENT_CHANNELS must include at least one enabled channel")
	}
	if c.PaymentEnvironment != "sandbox" && c.PaymentEnvironment != "production" {
		return fmt.Errorf("PAYMENT_ENV must be sandbox or production")
	}
	if c.Env == "production" && c.PaymentEnvironment != "production" {
		return fmt.Errorf("APP_ENV=production requires PAYMENT_ENV=production")
	}
	if c.PaymentPublicBaseURL == "" || !strings.HasPrefix(c.PaymentPublicBaseURL, "https://") {
		return fmt.Errorf("PAYMENT_PUBLIC_BASE_URL must use https when payments are enabled")
	}
	if len(c.PaymentEncryptionKey) < 32 {
		return fmt.Errorf("PAYMENT_DATA_ENCRYPTION_KEY must contain at least 32 characters")
	}
	for _, channel := range c.PaymentChannels {
		if err := c.validatePaymentChannel(channel); err != nil {
			return err
		}
	}
	if c.PaymentEnvironment == "production" && strings.Contains(strings.ToLower(c.AlipayGateway), "sandbox") {
		return fmt.Errorf("production payments cannot use an Alipay sandbox gateway")
	}
	if channelEnabled(c.PaymentChannels, "alipay") && !strings.HasPrefix(c.AlipayGateway, "https://") {
		return fmt.Errorf("ALIPAY_GATEWAY must use https")
	}
	if channelEnabled(c.PaymentChannels, "wechat") && !strings.HasPrefix(c.WeChatPayAPIBase, "https://") {
		return fmt.Errorf("WECHAT_PAY_API_BASE must use https")
	}
	return nil
}

func channelEnabled(channels []string, wanted string) bool {
	for _, channel := range channels {
		if channel == wanted {
			return true
		}
	}
	return false
}

func (c Config) validatePaymentChannel(channel string) error {
	required := map[string][]string{
		"apple":  {c.AppleBundleID, c.AppleAppID, c.AppleIssuerID, c.AppleKeyID, c.ApplePrivateKey},
		"wechat": {c.WeChatPayAppID, c.WeChatPayMerchantID, c.WeChatPayCertSerial, c.WeChatPayPrivateKey, c.WeChatPayAPIV3Key, c.WeChatPayPlanID},
		"alipay": {c.AlipayAppID, c.AlipayAppPrivateKey, c.AlipayAppPublicCert, c.AlipayPublicCert, c.AlipayRootCert, c.AlipayProductCode},
	}
	values, ok := required[channel]
	if !ok {
		return fmt.Errorf("unsupported payment channel %q", channel)
	}
	for _, value := range values {
		if strings.TrimSpace(value) == "" {
			return fmt.Errorf("payment channel %s is enabled but its credentials are incomplete", channel)
		}
	}
	return nil
}

func env(key, fallback string) string {
	if value, ok := fileValue(key); ok {
		return value
	}
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

// secret supports KEY_FILE for Docker secrets while retaining ordinary env use.
func secret(key string) string {
	if value, ok := fileValue(key); ok {
		return value
	}
	return strings.TrimSpace(os.Getenv(key))
}

func fileValue(key string) (string, bool) {
	path := strings.TrimSpace(os.Getenv(key + "_FILE"))
	if path == "" {
		return "", false
	}
	value, err := os.ReadFile(filepath.Clean(path))
	if err != nil {
		panic(fmt.Errorf("read %s_FILE: %w", key, err))
	}
	return strings.TrimSpace(string(value)), true
}

func splitCSV(value string) []string {
	var result []string
	seen := map[string]bool{}
	for _, item := range strings.Split(value, ",") {
		item = strings.ToLower(strings.TrimSpace(item))
		if item != "" && !seen[item] {
			seen[item] = true
			result = append(result, item)
		}
	}
	return result
}
