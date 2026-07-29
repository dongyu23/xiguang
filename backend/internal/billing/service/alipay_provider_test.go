package service

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/infra/config"
)

func testAlipayProvider(t *testing.T) *AlipayProvider {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	privateDER, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "alipay-test"},
		NotBefore:    now.Add(-time.Hour),
		NotAfter:     now.Add(time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	certDER, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	privatePEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: privateDER})
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: certDER})
	return NewAlipayProvider(config.Config{
		AlipayAppID:          "2026000000000000",
		AlipayAppPrivateKey:  base64.StdEncoding.EncodeToString(privatePEM),
		AlipayAppPublicCert:  base64.StdEncoding.EncodeToString(certPEM),
		AlipayPublicCert:     base64.StdEncoding.EncodeToString(certPEM),
		AlipayRootCert:       base64.StdEncoding.EncodeToString(certPEM),
		AlipayProductCode:    "CYCLE_PAY_AUTH_P",
		AlipaySignScene:      "INDUSTRY|DEFAULT",
		PaymentPublicBaseURL: "https://pay.example.test",
	})
}

func TestAlipayNotificationRSA2Verification(t *testing.T) {
	provider := testAlipayProvider(t)
	values := url.Values{
		"app_id":                {provider.cfg.AlipayAppID},
		"notify_id":             {"notify-1"},
		"sign_type":             {"RSA2"},
		"agreement_no":          {"agreement-1"},
		"external_agreement_no": {"order-1"},
		"status":                {"NORMAL"},
	}
	unsigned := make(url.Values, len(values))
	for key, value := range values {
		if key != "sign_type" {
			unsigned[key] = value
		}
	}
	privateKey, err := parseRSAPrivateKey(provider.cfg.AlipayAppPrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256([]byte(canonicalValues(unsigned)))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	values.Set("sign", base64.StdEncoding.EncodeToString(signature))
	if err := provider.VerifyNotification(values); err != nil {
		t.Fatal(err)
	}
	values.Set("status", "STOP")
	if err := provider.VerifyNotification(values); err == nil {
		t.Fatal("tampered Alipay notification was accepted")
	}
}

func TestAlipayAgreementPayloadIsSignedAndContainsNoPrivateKey(t *testing.T) {
	provider := testAlipayProvider(t)
	payload, err := provider.StartAgreement(t.Context(), domain.Order{PublicID: "order-1"}, domain.Product{
		Code: "starlight_year", Period: "year", PriceCents: 9800, TrialDays: 7,
	})
	if err != nil {
		t.Fatal(err)
	}
	orderString, _ := payload["order_string"].(string)
	if orderString == "" || strings.Contains(orderString, "PRIVATE") {
		t.Fatalf("unsafe or empty SDK payload: %q", orderString)
	}
	values, err := url.ParseQuery(orderString)
	if err != nil {
		t.Fatal(err)
	}
	if values.Get("method") != "alipay.user.agreement.page.sign" || values.Get("sign") == "" {
		t.Fatalf("unexpected signed agreement payload: %v", values)
	}
	if values.Get("app_cert_sn") == "" || values.Get("alipay_root_cert_sn") == "" {
		t.Fatalf("certificate serial numbers are missing: %v", values)
	}
}

func TestAlipayQueryReconcilesSuccessfulCharge(t *testing.T) {
	provider := testAlipayProvider(t)
	privateKey, err := parseRSAPrivateKey(provider.cfg.AlipayAppPrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil || r.Form.Get("method") != "alipay.trade.query" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		raw := json.RawMessage(`{"code":"10000","trade_no":"ali-trade-1","trade_status":"TRADE_SUCCESS","send_pay_date":"2026-07-28 12:00:00"}`)
		digest := sha256.Sum256(raw)
		signature, signErr := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, digest[:])
		if signErr != nil {
			http.Error(w, signErr.Error(), http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"alipay_trade_query_response": raw,
			"sign":                        base64.StdEncoding.EncodeToString(signature),
		})
	}))
	defer server.Close()
	provider.cfg.AlipayGateway = server.URL
	provider.client = server.Client()

	transactionID, paidAt, found, err := provider.QueryCharge(t.Context(), domain.RenewalCandidate{
		SubscriptionID: 4,
		PeriodEnd:      time.Unix(1000, 0),
	})
	if err != nil || !found || transactionID != "ali-trade-1" || paidAt.IsZero() {
		t.Fatalf("unexpected Alipay query result: %s %s %v %v", transactionID, paidAt, found, err)
	}
}
