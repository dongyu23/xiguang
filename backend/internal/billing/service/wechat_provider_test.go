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
	"io"
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

type fakeWechatClient struct {
	urls      []string
	bodies    []any
	responses []string
}

func (f *fakeWechatClient) Post(_ context.Context, endpoint string, body interface{}) (*core.APIResult, error) {
	f.urls = append(f.urls, endpoint)
	f.bodies = append(f.bodies, body)
	response := "{}"
	if len(f.responses) > 0 {
		response = f.responses[0]
		f.responses = f.responses[1:]
	}
	return &core.APIResult{Response: &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(response)),
		Header:     make(http.Header),
	}}, nil
}

func (f *fakeWechatClient) Get(_ context.Context, endpoint string) (*core.APIResult, error) {
	return f.Post(context.Background(), endpoint, nil)
}

func testWeChatProvider(client *fakeWechatClient) *WeChatProvider {
	return &WeChatProvider{
		cfg: config.Config{
			WeChatPayAppID:        "wx-app",
			WeChatPayMerchantID:   "merchant",
			WeChatPayPlanID:       "plan-1",
			WeChatPayAPIBase:      "https://api.example.test",
			WeChatPayContractPath: "/v3/papay/contracts/app-pre-entrust-sign",
			WeChatPayChargePath:   "/v3/papay/transactions",
			WeChatPayQueryPath:    "/v3/papay/transactions/out-trade-no/{out_trade_no}",
			WeChatPayCancelPath:   "/v3/papay/contracts/{contract_id}/terminate",
			PaymentPublicBaseURL:  "https://pay.example.test",
		},
		client:        client,
		notifyHandler: wechatnotify.NewEmptyHandler(),
	}
}

func TestWeChatAgreementPayloadUsesOfficialBusinessWebview(t *testing.T) {
	client := &fakeWechatClient{responses: []string{`{"pre_entrustweb_id":"entrust-1"}`}}
	provider := testWeChatProvider(client)
	payload, err := provider.StartAgreement(t.Context(), domain.Order{PublicID: "order-1"}, domain.Product{Code: "starlight_year"})
	if err != nil {
		t.Fatal(err)
	}
	if payload["pre_entrustweb_id"] != "entrust-1" || payload["business_type"] != 12 {
		t.Fatalf("unexpected WeChat SDK payload: %#v", payload)
	}
	request, ok := client.bodies[0].(map[string]any)
	if !ok || request["out_contract_code"] != "order-1" || request["plan_id"] != "plan-1" {
		t.Fatalf("unexpected WeChat agreement request: %#v", client.bodies[0])
	}
}

func TestWeChatChargeAndCancelUseAgreementID(t *testing.T) {
	client := &fakeWechatClient{responses: []string{
		`{"transaction_id":"wx-trade-1","trade_state":"SUCCESS","success_time":"2026-07-28T12:00:00+08:00"}`,
		`{"transaction_id":"wx-trade-1","trade_state":"SUCCESS","success_time":"2026-07-28T12:00:00+08:00"}`,
		`{}`,
	}}
	provider := testWeChatProvider(client)
	paidAtExpected, _ := time.Parse(time.RFC3339, "2026-07-28T12:00:00+08:00")
	transactionID, paidAt, err := provider.Charge(t.Context(), domain.RenewalCandidate{
		SubscriptionID:         8,
		ExternalSubscriptionID: "contract/a",
		PeriodEnd:              time.Unix(1000, 0),
		Product:                domain.Product{Code: "galaxy_month", PriceCents: 2800, Currency: "CNY"},
	})
	if err != nil || transactionID != "wx-trade-1" || !paidAt.Equal(paidAtExpected.UTC()) {
		t.Fatalf("unexpected WeChat charge result: %s %s %v", transactionID, paidAt, err)
	}
	request := client.bodies[0].(map[string]any)
	if request["contract_id"] != "contract/a" {
		t.Fatalf("charge omitted agreement: %#v", request)
	}
	queriedID, queriedAt, found, err := provider.QueryCharge(t.Context(), domain.RenewalCandidate{
		SubscriptionID: 8,
		PeriodEnd:      time.Unix(1000, 0),
	})
	if err != nil || !found || queriedID != "wx-trade-1" || !queriedAt.Equal(paidAtExpected.UTC()) {
		t.Fatalf("unexpected WeChat query result: %s %s %v %v", queriedID, queriedAt, found, err)
	}
	if !strings.Contains(client.urls[1], "out-trade-no/xg-8-1000?mchid=merchant") {
		t.Fatalf("unexpected WeChat query URL: %s", client.urls[1])
	}
	if err = provider.Cancel(t.Context(), "contract/a"); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(client.urls[2], "contract%2Fa/terminate") {
		t.Fatalf("agreement id was not escaped in cancel URL: %s", client.urls[2])
	}
}

func TestWeChatNotificationVerifiesSignatureAndDecryptsAESGCM(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber: big.NewInt(99),
		Subject:      pkix.Name{CommonName: "wechat-platform-test"},
		NotBefore:    now.Add(-time.Hour),
		NotAfter:     now.Add(time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
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
	block, _ := aes.NewCipher([]byte(apiV3Key))
	aead, _ := cipher.NewGCM(block)
	nonce := "0123456789ab"
	associatedData := "transaction"
	content := `{"mchid":"merchant","appid":"wx-app","contract_id":"contract-1","trade_state":"SUCCESS"}`
	ciphertext := aead.Seal(nil, []byte(nonce), []byte(content), []byte(associatedData))
	bodyMap := map[string]any{
		"id":            "event-1",
		"create_time":   now.Format(time.RFC3339),
		"event_type":    "TRANSACTION.SUCCESS",
		"resource_type": "encrypt-resource",
		"resource": map[string]string{
			"algorithm":       "AEAD_AES_256_GCM",
			"ciphertext":      base64.StdEncoding.EncodeToString(ciphertext),
			"associated_data": associatedData,
			"nonce":           nonce,
		},
	}
	body, _ := json.Marshal(bodyMap)
	timestamp := strconv.FormatInt(now.Unix(), 10)
	headerNonce := "notify-nonce"
	message := timestamp + "\n" + headerNonce + "\n" + string(body) + "\n"
	digest := sha256.Sum256([]byte(message))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	getter := core.NewCertificateMapWithList([]*x509.Certificate{cert})
	verifier := verifiers.NewSHA256WithRSAVerifier(getter)
	handler, err := wechatnotify.NewRSANotifyHandler(apiV3Key, verifier)
	if err != nil {
		t.Fatal(err)
	}
	provider := testWeChatProvider(&fakeWechatClient{})
	provider.notifyHandler = handler
	request, _ := http.NewRequest(http.MethodPost, "https://example.test/webhook", strings.NewReader(string(body)))
	request.Header.Set("Wechatpay-Timestamp", timestamp)
	request.Header.Set("Wechatpay-Nonce", headerNonce)
	request.Header.Set("Wechatpay-Serial", strings.ToUpper(cert.SerialNumber.Text(16)))
	request.Header.Set("Wechatpay-Signature", base64.StdEncoding.EncodeToString(signature))
	var decoded map[string]any
	notification, err := provider.ParseNotification(t.Context(), request, &decoded)
	if err != nil {
		t.Fatal(err)
	}
	if notification.ID != "event-1" || decoded["contract_id"] != "contract-1" {
		t.Fatalf("unexpected decrypted notification: %#v %#v", notification, decoded)
	}

	request, _ = http.NewRequest(http.MethodPost, "https://example.test/webhook", strings.NewReader(string(body)+" "))
	request.Header.Set("Wechatpay-Timestamp", timestamp)
	request.Header.Set("Wechatpay-Nonce", headerNonce)
	request.Header.Set("Wechatpay-Serial", strings.ToUpper(cert.SerialNumber.Text(16)))
	request.Header.Set("Wechatpay-Signature", base64.StdEncoding.EncodeToString(signature))
	if _, err = provider.ParseNotification(t.Context(), request, &decoded); err == nil {
		t.Fatal("tampered WeChat notification was accepted")
	}
}
