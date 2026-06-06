package provider

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"math/big"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"nhooyr.io/websocket"

	"xiguang/backend/internal/infra/config"
)

type RealtimeProxy struct {
	appID     string
	secretID  string
	secretKey string
	host      string
	engine    string
	now       func() time.Time
}

func NewRealtimeProxy(cfg config.Config) *RealtimeProxy {
	return &RealtimeProxy{
		appID:     cfg.TencentASRAppID,
		secretID:  cfg.TencentASRSecretID,
		secretKey: cfg.TencentASRSecretKey,
		host:      cfg.TencentASRRealtimeHost,
		engine:    cfg.TencentASREngine,
		now:       time.Now,
	}
}

func (p *RealtimeProxy) Serve(ctx context.Context, client *websocket.Conn) error {
	defer client.Close(websocket.StatusNormalClosure, "")
	if strings.TrimSpace(p.appID) == "" || strings.TrimSpace(p.secretID) == "" || strings.TrimSpace(p.secretKey) == "" {
		_ = writeRealtimeError(ctx, client, "asr_not_configured", "语音识别服务还没有配置完成。")
		return ErrNotConfigured
	}
	upstreamURL, err := p.realtimeURL()
	if err != nil {
		_ = writeRealtimeError(ctx, client, "asr_failed", "语音识别连接暂时不可用。")
		return err
	}

	upstream, _, err := websocket.Dial(ctx, upstreamURL, &websocket.DialOptions{
		HTTPClient: &http.Client{Timeout: 10 * time.Second},
	})
	if err != nil {
		_ = writeRealtimeError(ctx, client, "asr_failed", "语音识别连接暂时不可用。")
		return err
	}
	defer upstream.Close(websocket.StatusNormalClosure, "")

	errCh := make(chan error, 2)
	go func() { errCh <- pipeClientAudio(ctx, client, upstream) }()
	go func() { errCh <- pipeTencentResult(ctx, upstream, client) }()
	err = <-errCh
	if err != nil && !isNormalWebSocketClose(err) {
		return err
	}
	return nil
}

func (p *RealtimeProxy) realtimeURL() (string, error) {
	host := strings.TrimSpace(p.host)
	if host == "" {
		host = "asr.cloud.tencent.com"
	}
	engine := strings.TrimSpace(p.engine)
	if engine == "" {
		engine = "16k_zh"
	}
	now := p.now().Unix()
	nonce, err := randomNonce()
	if err != nil {
		return "", err
	}
	params := map[string]string{
		"engine_model_type": engine,
		"expired":           strconv.FormatInt(now+24*60*60, 10),
		"filter_dirty":      "0",
		"filter_modal":      "0",
		"filter_punc":       "0",
		"needvad":           "1",
		"nonce":             nonce,
		"secretid":          p.secretID,
		"timestamp":         strconv.FormatInt(now, 10),
		"voice_format":      "1",
		"voice_id":          randomVoiceID(),
	}

	canonical := canonicalRealtimeURL(host, p.appID, params)
	mac := hmac.New(sha1.New, []byte(p.secretKey))
	_, _ = mac.Write([]byte(canonical))
	params["signature"] = base64.StdEncoding.EncodeToString(mac.Sum(nil))

	values := url.Values{}
	keys := make([]string, 0, len(params))
	for key := range params {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		values.Set(key, params[key])
	}
	return "wss://" + host + "/asr/v2/" + p.appID + "?" + values.Encode(), nil
}

func canonicalRealtimeURL(host, appID string, params map[string]string) string {
	keys := make([]string, 0, len(params))
	for key := range params {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, key+"="+params[key])
	}
	return host + "/asr/v2/" + appID + "?" + strings.Join(parts, "&")
}

func pipeClientAudio(ctx context.Context, client, upstream *websocket.Conn) error {
	for {
		messageType, data, err := client.Read(ctx)
		if err != nil {
			_ = upstream.Write(ctx, websocket.MessageText, []byte(`{"type":"end"}`))
			return err
		}
		if messageType == websocket.MessageBinary {
			if len(data) == 0 {
				continue
			}
			if err := upstream.Write(ctx, websocket.MessageBinary, data); err != nil {
				return err
			}
			continue
		}
		if strings.Contains(string(data), `"type":"end"`) || strings.Contains(string(data), `"type": "end"`) {
			if err := upstream.Write(ctx, websocket.MessageText, []byte(`{"type":"end"}`)); err != nil {
				return err
			}
			return nil
		}
	}
}

func pipeTencentResult(ctx context.Context, upstream, client *websocket.Conn) error {
	for {
		messageType, data, err := upstream.Read(ctx)
		if err != nil {
			return err
		}
		if messageType != websocket.MessageText {
			continue
		}
		out := normalizeRealtimeMessage(data)
		if err := client.Write(ctx, websocket.MessageText, out); err != nil {
			return err
		}
		if strings.Contains(string(data), `"final":1`) {
			return nil
		}
	}
}

func normalizeRealtimeMessage(raw []byte) []byte {
	var msg struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Final   int    `json:"final"`
		Result  *struct {
			SliceType int    `json:"slice_type"`
			Index     int    `json:"index"`
			Text      string `json:"voice_text_str"`
		} `json:"result"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil {
		return raw
	}
	if msg.Code != 0 {
		body, _ := json.Marshal(map[string]any{
			"type":    "error",
			"code":    msg.Code,
			"message": msg.Message,
		})
		return body
	}
	if msg.Final == 1 {
		return []byte(`{"type":"final"}`)
	}
	if msg.Result == nil {
		return []byte(`{"type":"ready"}`)
	}
	body, _ := json.Marshal(map[string]any{
		"type":       "result",
		"text":       msg.Result.Text,
		"slice_type": msg.Result.SliceType,
		"index":      msg.Result.Index,
		"stable":     msg.Result.SliceType == 2,
	})
	return body
}

func writeRealtimeError(ctx context.Context, conn *websocket.Conn, code, message string) error {
	body, _ := json.Marshal(map[string]string{
		"type":    "error",
		"code":    code,
		"message": message,
	})
	return conn.Write(ctx, websocket.MessageText, body)
}

func randomNonce() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(9999999999))
	if err != nil {
		return "", err
	}
	return strconv.FormatInt(n.Int64()+1, 10), nil
}

func randomVoiceID() string {
	var b [16]byte
	if _, err := io.ReadFull(rand.Reader, b[:]); err != nil {
		return strconv.FormatInt(time.Now().UnixNano(), 36)
	}
	return hex.EncodeToString(b[:])
}

func isNormalWebSocketClose(err error) bool {
	status := websocket.CloseStatus(err)
	return status == websocket.StatusNormalClosure ||
		status == websocket.StatusGoingAway ||
		status == websocket.StatusNoStatusRcvd
}
