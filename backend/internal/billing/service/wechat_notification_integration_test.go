package service

import (
	"context"
	"crypto"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/wechatpay-apiv3/wechatpay-go/core"
	"github.com/wechatpay-apiv3/wechatpay-go/core/auth/verifiers"
	wechatnotify "github.com/wechatpay-apiv3/wechatpay-go/core/notify"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/infra/config"
)

type wechatSmokeSigner struct {
	privateKey *rsa.PrivateKey
	serial     string
	apiV3Key   string
	provider   *WeChatProvider
}

func newWechatSmokeSigner(t *testing.T) wechatSmokeSigner {
	t.Helper()
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber: big.NewInt(202), Subject: pkix.Name{CommonName: "WeChat smoke platform"},
		NotBefore: now.Add(-time.Hour), NotAfter: now.Add(24 * time.Hour), KeyUsage: x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &privateKey.PublicKey, privateKey)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	apiV3Key := "0123456789abcdef0123456789abcdef"
	getter := core.NewCertificateMapWithList([]*x509.Certificate{cert})
	handler, err := wechatnotify.NewRSANotifyHandler(apiV3Key, verifiers.NewSHA256WithRSAVerifier(getter))
	if err != nil {
		t.Fatal(err)
	}
	provider := testWeChatProvider(&fakeWechatClient{responses: []string{`{"pre_entrustweb_id":"entrust-smoke"}`}})
	provider.notifyHandler = handler
	return wechatSmokeSigner{
		privateKey: privateKey, serial: strings.ToUpper(cert.SerialNumber.Text(16)), apiV3Key: apiV3Key, provider: provider,
	}
}

func (s wechatSmokeSigner) request(t *testing.T, eventID, eventType string, content map[string]any, createdAt time.Time) *http.Request {
	t.Helper()
	plain, err := json.Marshal(content)
	if err != nil {
		t.Fatal(err)
	}
	block, err := aes.NewCipher([]byte(s.apiV3Key))
	if err != nil {
		t.Fatal(err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatal(err)
	}
	nonce := "0123456789ab"
	associatedData := "billing-smoke"
	ciphertext := aead.Seal(nil, []byte(nonce), plain, []byte(associatedData))
	body, err := json.Marshal(map[string]any{
		"id": eventID, "create_time": createdAt.Format(time.RFC3339), "event_type": eventType, "resource_type": "encrypt-resource",
		"resource": map[string]string{
			"algorithm": "AEAD_AES_256_GCM", "ciphertext": base64.StdEncoding.EncodeToString(ciphertext),
			"associated_data": associatedData, "nonce": nonce,
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	timestamp := strconv.FormatInt(createdAt.Unix(), 10)
	headerNonce := "smoke-notify-nonce"
	digest := sha256.Sum256([]byte(timestamp + "\n" + headerNonce + "\n" + string(body) + "\n"))
	signature, err := rsa.SignPKCS1v15(rand.Reader, s.privateKey, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	request, err := http.NewRequestWithContext(context.Background(), http.MethodPost, "https://pay.example.test/api/v1/billing/webhooks/wechat", strings.NewReader(string(body)))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Wechatpay-Timestamp", timestamp)
	request.Header.Set("Wechatpay-Nonce", headerNonce)
	request.Header.Set("Wechatpay-Serial", s.serial)
	request.Header.Set("Wechatpay-Signature", base64.StdEncoding.EncodeToString(signature))
	return request
}

func TestWeChatSignedNotificationsPurchaseReplayAndOutOfOrderRefund(t *testing.T) {
	repo, pool, userID := serviceIntegrationRepo(t)
	const externalProductID = "com.xiguang.membership.starlight.month"
	var wasEnabled bool
	if err := pool.QueryRow(t.Context(), `SELECT enabled FROM billing_provider_products WHERE provider='wechat' AND external_product_id=$1`, externalProductID).Scan(&wasEnabled); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now() WHERE provider='wechat' AND external_product_id=$1`, externalProductID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `UPDATE billing_provider_products SET enabled=$2 WHERE provider='wechat' AND external_product_id=$1`, externalProductID, wasEnabled)
	})
	signer := newWechatSmokeSigner(t)
	paymentService := New(repo, config.Config{
		PaymentEnabled: true, PaymentEnvironment: "sandbox", PaymentChannels: []string{"wechat"},
		PaymentEncryptionKey: "01234567890123456789012345678901",
		WeChatPayAppID:       "wx-app", WeChatPayMerchantID: "merchant",
	}, signer.provider)
	paymentService.initialized.Store(true)
	prefix := fmt.Sprintf("wechat-smoke-%d", time.Now().UnixNano())
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM payment_events WHERE provider='wechat' AND external_event_id LIKE $1`, prefix+"%")
		_, _ = pool.Exec(context.Background(), `DELETE FROM pending_payment_refunds WHERE provider='wechat' AND transaction_id LIKE $1`, prefix+"%")
	})
	result, err := paymentService.CreateSubscription(t.Context(), userID, domain.CreateSubscriptionRequest{
		Provider: "wechat", ProductCode: "starlight_month", ClientRequestID: prefix + "-checkout",
	})
	if err != nil || result.Order.Status != "pending" || result.SDKPayload["pre_entrustweb_id"] != "entrust-smoke" {
		t.Fatalf("WeChat checkout = %+v, %v", result, err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	contractID := prefix + "-contract"
	agreementRequest := signer.request(t, prefix+"-agreement-event", "PAPAY.CONTRACT.SIGNED", map[string]any{
		"mchid": "merchant", "appid": "wx-app", "out_contract_code": result.Order.PublicID,
		"contract_id": contractID, "contract_state": "NORMAL", "openid": prefix + "-openid",
	}, now)
	processed, err := paymentService.ProcessWeChatNotification(t.Context(), agreementRequest)
	if err != nil || !processed {
		t.Fatalf("WeChat agreement notification = %v, %v", processed, err)
	}
	tradeID := prefix + "-trade"
	tradeContent := map[string]any{
		"mchid": "merchant", "appid": "wx-app", "contract_id": contractID,
		"transaction_id": tradeID, "trade_state": "SUCCESS", "success_time": now.Format(time.RFC3339),
		"amount": map[string]any{"total": 1200, "currency": "CNY"},
	}
	tradeRequest := signer.request(t, prefix+"-trade-event", "TRANSACTION.SUCCESS", tradeContent, now)
	processed, err = paymentService.ProcessWeChatNotification(t.Context(), tradeRequest)
	if err != nil || !processed {
		t.Fatalf("WeChat trade notification = %v, %v", processed, err)
	}
	entitlement, err := repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "starlight" || entitlement.Status != "active" {
		t.Fatalf("WeChat purchase entitlement = %+v, %v", entitlement, err)
	}
	replayRequest := signer.request(t, prefix+"-trade-event", "TRANSACTION.SUCCESS", tradeContent, now)
	processed, err = paymentService.ProcessWeChatNotification(t.Context(), replayRequest)
	if err != nil || processed {
		t.Fatalf("WeChat replay = %v, %v", processed, err)
	}

	futureTradeID := prefix + "-future-trade"
	refundRequest := signer.request(t, prefix+"-refund-event", "REFUND.SUCCESS", map[string]any{
		"mchid": "merchant", "appid": "wx-app", "transaction_id": futureTradeID, "refund_status": "SUCCESS",
	}, now.Add(time.Minute))
	processed, err = paymentService.ProcessWeChatNotification(t.Context(), refundRequest)
	if err != nil || !processed {
		t.Fatalf("WeChat early refund = %v, %v", processed, err)
	}
	futureTradeRequest := signer.request(t, prefix+"-future-trade-event", "TRANSACTION.SUCCESS", map[string]any{
		"mchid": "merchant", "appid": "wx-app", "contract_id": contractID,
		"transaction_id": futureTradeID, "trade_state": "SUCCESS", "success_time": now.Add(2 * time.Minute).Format(time.RFC3339),
		"amount": map[string]any{"total": 1200, "currency": "CNY"},
	}, now.Add(2*time.Minute))
	processed, err = paymentService.ProcessWeChatNotification(t.Context(), futureTradeRequest)
	if err != nil || !processed {
		t.Fatalf("WeChat trade following early refund = %v, %v", processed, err)
	}
	entitlement, err = repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "glimmer" || entitlement.Status != "revoked" {
		t.Fatalf("WeChat out-of-order refund entitlement = %+v, %v", entitlement, err)
	}
}
