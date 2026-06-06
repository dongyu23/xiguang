package provider

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"xiguang/backend/internal/infra/config"
)

const (
	tencentASRService = "asr"
	tencentASRAction  = "SentenceRecognition"
	tencentASRVersion = "2019-06-14"
)

type Tencent struct {
	appID     string
	secretID  string
	secretKey string
	region    string
	endpoint  string
	engine    string
	client    *http.Client
	now       func() time.Time
}

func NewTencent(cfg config.Config) *Tencent {
	return &Tencent{
		appID:     cfg.TencentASRAppID,
		secretID:  cfg.TencentASRSecretID,
		secretKey: cfg.TencentASRSecretKey,
		region:    cfg.TencentASRRegion,
		endpoint:  cfg.TencentASREndpoint,
		engine:    cfg.TencentASREngine,
		client:    &http.Client{Timeout: 15 * time.Second},
		now:       time.Now,
	}
}

func (p *Tencent) Recognize(ctx context.Context, req RecognizeRequest) (RecognizeResponse, error) {
	if strings.TrimSpace(p.secretID) == "" || strings.TrimSpace(p.secretKey) == "" {
		return RecognizeResponse{}, ErrNotConfigured
	}
	format := strings.ToLower(strings.TrimSpace(req.Format))
	if format == "" {
		format = "wav"
	}
	engine := strings.TrimSpace(p.engine)
	if engine == "" {
		engine = "16k_zh"
	}
	region := strings.TrimSpace(p.region)
	if region == "" {
		region = "ap-shanghai"
	}
	endpoint := strings.TrimSpace(p.endpoint)
	if endpoint == "" {
		endpoint = "asr.tencentcloudapi.com"
	}

	payload := map[string]any{
		"SubServiceType": 2,
		"ProjectId":      0,
		"EngSerViceType": engine,
		"SourceType":     1,
		"VoiceFormat":    format,
		"Data":           req.AudioBase64,
		"DataLen":        req.DataLen,
	}
	if req.SampleRate > 0 {
		payload["InputSampleRate"] = req.SampleRate
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return RecognizeResponse{}, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://"+endpoint, bytes.NewReader(body))
	if err != nil {
		return RecognizeResponse{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json; charset=utf-8")
	httpReq.Header.Set("Host", endpoint)
	httpReq.Header.Set("X-TC-Action", tencentASRAction)
	httpReq.Header.Set("X-TC-Version", tencentASRVersion)
	httpReq.Header.Set("X-TC-Region", region)
	httpReq.Header.Set("X-TC-Timestamp", strconv.FormatInt(p.now().Unix(), 10))
	httpReq.Header.Set("Authorization", p.authorization(httpReq, body))

	resp, err := p.client.Do(httpReq)
	if err != nil {
		return RecognizeResponse{}, err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return RecognizeResponse{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return RecognizeResponse{}, fmt.Errorf("tencent asr http %d: %s", resp.StatusCode, string(respBody))
	}

	var parsed struct {
		Response struct {
			Result    string `json:"Result"`
			RequestID string `json:"RequestId"`
			Error     *struct {
				Code    string `json:"Code"`
				Message string `json:"Message"`
			} `json:"Error"`
		} `json:"Response"`
	}
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return RecognizeResponse{}, err
	}
	if parsed.Response.Error != nil {
		return RecognizeResponse{}, fmt.Errorf("tencent asr %s: %s", parsed.Response.Error.Code, parsed.Response.Error.Message)
	}
	return RecognizeResponse{Text: strings.TrimSpace(parsed.Response.Result)}, nil
}

func (p *Tencent) authorization(req *http.Request, payload []byte) string {
	timestamp := req.Header.Get("X-TC-Timestamp")
	t, _ := strconv.ParseInt(timestamp, 10, 64)
	date := time.Unix(t, 0).UTC().Format("2006-01-02")

	canonicalHeaders := "content-type:" + strings.ToLower(req.Header.Get("Content-Type")) + "\n" +
		"host:" + req.URL.Host + "\n"
	signedHeaders := "content-type;host"
	canonicalRequest := strings.Join([]string{
		req.Method,
		"/",
		"",
		canonicalHeaders,
		signedHeaders,
		sha256Hex(payload),
	}, "\n")

	credentialScope := date + "/" + tencentASRService + "/tc3_request"
	stringToSign := strings.Join([]string{
		"TC3-HMAC-SHA256",
		timestamp,
		credentialScope,
		sha256Hex([]byte(canonicalRequest)),
	}, "\n")

	secretDate := hmacSHA256([]byte("TC3"+p.secretKey), date)
	secretService := hmacSHA256(secretDate, tencentASRService)
	secretSigning := hmacSHA256(secretService, "tc3_request")
	signature := hex.EncodeToString(hmacSHA256(secretSigning, stringToSign))

	return fmt.Sprintf("TC3-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		p.secretID, credentialScope, signedHeaders, signature)
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func hmacSHA256(key []byte, msg string) []byte {
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write([]byte(msg))
	return mac.Sum(nil)
}
