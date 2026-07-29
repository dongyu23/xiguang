package service

import (
	"context"
	"crypto"
	"crypto/md5"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/infra/config"
)

type AlipayProvider struct {
	cfg    config.Config
	client *http.Client
}

func NewAlipayProvider(cfg config.Config) *AlipayProvider {
	return &AlipayProvider{cfg: cfg, client: &http.Client{Timeout: 20 * time.Second}}
}

func (p *AlipayProvider) Name() string { return "alipay" }

func (p *AlipayProvider) VerifyProducts(_ context.Context, products []domain.Product) ([]string, error) {
	privateKey, err := parseRSAPrivateKey(p.cfg.AlipayAppPrivateKey)
	if err != nil {
		return nil, err
	}
	publicKey, err := parseAlipayPublicKey(p.cfg.AlipayPublicCert)
	if err != nil {
		return nil, err
	}
	test := []byte("xiguang-alipay-configuration-check")
	digest := sha256.Sum256(test)
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, digest[:])
	if err != nil {
		return nil, err
	}
	appCert, err := parseCertificate(p.cfg.AlipayAppPublicCert)
	if err != nil {
		return nil, fmt.Errorf("parse Alipay app certificate: %w", err)
	}
	appPublicKey, ok := appCert.PublicKey.(*rsa.PublicKey)
	if !ok || appPublicKey.N.Cmp(privateKey.N) != 0 || appPublicKey.E != privateKey.E {
		return nil, errors.New("Alipay app certificate does not match the app private key")
	}
	if _, err = alipayRootCertSN(p.cfg.AlipayRootCert); err != nil {
		return nil, fmt.Errorf("parse Alipay root certificate: %w", err)
	}
	// The application key and Alipay response key are expected to be different.
	_ = publicKey
	if len(signature) == 0 || strings.TrimSpace(p.cfg.AlipayProductCode) == "" {
		return nil, errors.New("invalid Alipay recurring-payment configuration")
	}
	ids := make([]string, 0, len(products))
	for _, product := range products {
		if product.ExternalProductID == "" {
			return nil, fmt.Errorf("missing Alipay mapping for %s", product.Code)
		}
		ids = append(ids, product.ExternalProductID)
	}
	return ids, nil
}

func (p *AlipayProvider) StartAgreement(_ context.Context, order domain.Order, product domain.Product) (map[string]any, error) {
	access, _ := json.Marshal(map[string]string{"channel": "ALIPAYAPP"})
	biz := map[string]any{
		"external_agreement_no": order.PublicID,
		"personal_product_code": p.cfg.AlipayProductCode,
		"sign_scene":            p.cfg.AlipaySignScene,
		"access_params":         string(access),
		"period_rule_params": map[string]any{
			"period_type":   "MONTH",
			"period":        map[bool]int{true: 12, false: 1}[product.Period == "year"],
			"execute_time":  time.Now().AddDate(0, 0, product.TrialDays).Format("2006-01-02"),
			"single_amount": fmt.Sprintf("%.2f", float64(product.PriceCents)/100),
		},
	}
	bizJSON, err := json.Marshal(biz)
	if err != nil {
		return nil, err
	}
	params := p.baseParams("alipay.user.agreement.page.sign")
	params.Set("notify_url", p.cfg.PaymentPublicBaseURL+"/api/v1/billing/webhooks/alipay")
	params.Set("biz_content", string(bizJSON))
	if err = p.sign(params); err != nil {
		return nil, err
	}
	return map[string]any{"order_string": params.Encode(), "method": "agreement_sign"}, nil
}

func (p *AlipayProvider) Charge(ctx context.Context, candidate domain.RenewalCandidate) (string, time.Time, error) {
	outTradeNo := renewalOutTradeNo(candidate)
	bizJSON, _ := json.Marshal(map[string]any{
		"out_trade_no": outTradeNo,
		"total_amount": fmt.Sprintf("%.2f", float64(candidate.Product.PriceCents)/100),
		"subject":      "隙光会员 " + candidate.Product.Code,
		"product_code": "CYCLE_PAY_AUTH",
		"agreement_params": map[string]string{
			"agreement_no": candidate.ExternalSubscriptionID,
		},
	})
	params := p.baseParams("alipay.trade.pay")
	params.Set("notify_url", p.cfg.PaymentPublicBaseURL+"/api/v1/billing/webhooks/alipay")
	params.Set("biz_content", string(bizJSON))
	if err := p.sign(params); err != nil {
		return "", time.Time{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.cfg.AlipayGateway, strings.NewReader(params.Encode()))
	if err != nil {
		return "", time.Time{}, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	resp, err := p.client.Do(req)
	if err != nil {
		return "", time.Time{}, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return "", time.Time{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", time.Time{}, fmt.Errorf("Alipay HTTP %d", resp.StatusCode)
	}
	var envelope struct {
		Response json.RawMessage `json:"alipay_trade_pay_response"`
		Sign     string          `json:"sign"`
	}
	if err = json.Unmarshal(body, &envelope); err != nil || len(envelope.Response) == 0 || envelope.Sign == "" {
		return "", time.Time{}, errors.New("invalid Alipay response")
	}
	if err = p.verify(envelope.Response, envelope.Sign); err != nil {
		return "", time.Time{}, err
	}
	var result struct {
		Code    string `json:"code"`
		SubCode string `json:"sub_code"`
		TradeNo string `json:"trade_no"`
	}
	if err = json.Unmarshal(envelope.Response, &result); err != nil {
		return "", time.Time{}, err
	}
	if result.Code != "10000" || result.TradeNo == "" {
		return "", time.Time{}, fmt.Errorf("Alipay charge failed: %s/%s", result.Code, result.SubCode)
	}
	return result.TradeNo, time.Now().UTC(), nil
}

func (p *AlipayProvider) QueryCharge(ctx context.Context, candidate domain.RenewalCandidate) (string, time.Time, bool, error) {
	bizJSON, _ := json.Marshal(map[string]string{"out_trade_no": renewalOutTradeNo(candidate)})
	params := p.baseParams("alipay.trade.query")
	params.Set("biz_content", string(bizJSON))
	if err := p.sign(params); err != nil {
		return "", time.Time{}, false, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.cfg.AlipayGateway, strings.NewReader(params.Encode()))
	if err != nil {
		return "", time.Time{}, false, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	resp, err := p.client.Do(req)
	if err != nil {
		return "", time.Time{}, false, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return "", time.Time{}, false, err
	}
	var envelope struct {
		Response json.RawMessage `json:"alipay_trade_query_response"`
		Sign     string          `json:"sign"`
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 || json.Unmarshal(body, &envelope) != nil || len(envelope.Response) == 0 {
		return "", time.Time{}, false, fmt.Errorf("invalid Alipay query response (HTTP %d)", resp.StatusCode)
	}
	if err = p.verify(envelope.Response, envelope.Sign); err != nil {
		return "", time.Time{}, false, err
	}
	var result struct {
		Code        string `json:"code"`
		SubCode     string `json:"sub_code"`
		TradeNo     string `json:"trade_no"`
		TradeStatus string `json:"trade_status"`
		SendPayDate string `json:"send_pay_date"`
	}
	if err = json.Unmarshal(envelope.Response, &result); err != nil {
		return "", time.Time{}, false, err
	}
	if result.SubCode == "ACQ.TRADE_NOT_EXIST" {
		return "", time.Time{}, false, nil
	}
	if result.Code != "10000" {
		return "", time.Time{}, false, fmt.Errorf("Alipay query failed: %s/%s", result.Code, result.SubCode)
	}
	if result.TradeStatus != "TRADE_SUCCESS" && result.TradeStatus != "TRADE_FINISHED" {
		return "", time.Time{}, false, nil
	}
	return result.TradeNo, parseAlipayTime(result.SendPayDate), true, nil
}

func (p *AlipayProvider) Cancel(ctx context.Context, agreementID string) error {
	bizJSON, _ := json.Marshal(map[string]string{"agreement_no": agreementID})
	params := p.baseParams("alipay.user.agreement.unsign")
	params.Set("biz_content", string(bizJSON))
	if err := p.sign(params); err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.cfg.AlipayGateway, strings.NewReader(params.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return err
	}
	var envelope struct {
		Response json.RawMessage `json:"alipay_user_agreement_unsign_response"`
		Sign     string          `json:"sign"`
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 || json.Unmarshal(body, &envelope) != nil || len(envelope.Response) == 0 {
		return fmt.Errorf("invalid Alipay unsign response (HTTP %d)", resp.StatusCode)
	}
	if err = p.verify(envelope.Response, envelope.Sign); err != nil {
		return err
	}
	var result struct {
		Code    string `json:"code"`
		SubCode string `json:"sub_code"`
	}
	if err = json.Unmarshal(envelope.Response, &result); err != nil {
		return err
	}
	if result.Code != "10000" {
		return fmt.Errorf("Alipay unsign failed: %s/%s", result.Code, result.SubCode)
	}
	return nil
}

func (p *AlipayProvider) VerifyNotification(values url.Values) error {
	signature := values.Get("sign")
	if signature == "" || values.Get("sign_type") != "RSA2" {
		return errors.New("missing Alipay RSA2 signature")
	}
	clone := make(url.Values, len(values))
	for key, value := range values {
		if key != "sign" && key != "sign_type" && len(value) > 0 && value[0] != "" {
			clone[key] = value
		}
	}
	return p.verify([]byte(canonicalValues(clone)), signature)
}

func (p *AlipayProvider) baseParams(method string) url.Values {
	values := url.Values{
		"app_id":    {p.cfg.AlipayAppID},
		"method":    {method},
		"format":    {"JSON"},
		"charset":   {"utf-8"},
		"sign_type": {"RSA2"},
		"timestamp": {time.Now().Format("2006-01-02 15:04:05")},
		"version":   {"1.0"},
	}
	if sn, err := alipayCertSN(p.cfg.AlipayAppPublicCert); err == nil {
		values.Set("app_cert_sn", sn)
	}
	if sn, err := alipayRootCertSN(p.cfg.AlipayRootCert); err == nil {
		values.Set("alipay_root_cert_sn", sn)
	}
	return values
}

func (p *AlipayProvider) sign(values url.Values) error {
	key, err := parseRSAPrivateKey(p.cfg.AlipayAppPrivateKey)
	if err != nil {
		return err
	}
	digest := sha256.Sum256([]byte(canonicalValues(values)))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err == nil {
		values.Set("sign", base64.StdEncoding.EncodeToString(signature))
	}
	return err
}

func (p *AlipayProvider) verify(content []byte, encodedSignature string) error {
	key, err := parseAlipayPublicKey(p.cfg.AlipayPublicCert)
	if err != nil {
		return err
	}
	signature, err := base64.StdEncoding.DecodeString(encodedSignature)
	if err != nil {
		return err
	}
	digest := sha256.Sum256(content)
	return rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], signature)
}

func canonicalValues(values url.Values) string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, key+"="+values.Get(key))
	}
	return strings.Join(parts, "&")
}

func parseRSAPrivateKey(encoded string) (*rsa.PrivateKey, error) {
	raw := decodePEMMaterial(encoded)
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("Alipay app private key is not PEM")
	}
	if parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if key, ok := parsed.(*rsa.PrivateKey); ok {
			return key, nil
		}
	}
	return x509.ParsePKCS1PrivateKey(block.Bytes)
}

func parseAlipayPublicKey(encoded string) (*rsa.PublicKey, error) {
	raw := decodePEMMaterial(encoded)
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("Alipay public certificate is not PEM")
	}
	if cert, err := x509.ParseCertificate(block.Bytes); err == nil {
		key, ok := cert.PublicKey.(*rsa.PublicKey)
		if !ok {
			return nil, errors.New("Alipay certificate key is not RSA")
		}
		if time.Now().Before(cert.NotBefore) || time.Now().After(cert.NotAfter) {
			return nil, errors.New("Alipay public certificate is expired or not active")
		}
		return key, nil
	}
	parsed, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	key, ok := parsed.(*rsa.PublicKey)
	if !ok {
		return nil, errors.New("Alipay public key is not RSA")
	}
	return key, nil
}

func parseCertificate(encoded string) (*x509.Certificate, error) {
	raw := decodePEMMaterial(encoded)
	block, _ := pem.Decode(raw)
	if block == nil {
		return nil, errors.New("certificate is not PEM")
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, err
	}
	if time.Now().Before(cert.NotBefore) || time.Now().After(cert.NotAfter) {
		return nil, errors.New("certificate is expired or not active")
	}
	return cert, nil
}

func alipayCertSN(encoded string) (string, error) {
	cert, err := parseCertificate(encoded)
	if err != nil {
		return "", err
	}
	sum := md5.Sum([]byte(cert.Issuer.String() + cert.SerialNumber.String()))
	return hex.EncodeToString(sum[:]), nil
}

func alipayRootCertSN(encoded string) (string, error) {
	rest := decodePEMMaterial(encoded)
	var serials []string
	for len(rest) > 0 {
		block, remaining := pem.Decode(rest)
		rest = remaining
		if block == nil {
			break
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			return "", err
		}
		if cert.PublicKeyAlgorithm != x509.RSA {
			continue
		}
		sum := md5.Sum([]byte(cert.Issuer.String() + cert.SerialNumber.String()))
		serials = append(serials, hex.EncodeToString(sum[:]))
	}
	if len(serials) == 0 {
		return "", errors.New("Alipay root certificate contains no RSA certificate")
	}
	return strings.Join(serials, "_"), nil
}

func decodePEMMaterial(value string) []byte {
	value = strings.TrimSpace(value)
	if decoded, err := base64.StdEncoding.DecodeString(value); err == nil {
		return decoded
	}
	return []byte(value)
}

func parseAlipayTime(value string) time.Time {
	for _, layout := range []string{"2006-01-02 15:04:05", time.RFC3339} {
		if parsed, err := time.ParseInLocation(layout, value, time.Local); err == nil {
			return parsed.UTC()
		}
	}
	if unix, err := strconv.ParseInt(value, 10, 64); err == nil {
		return time.Unix(unix, 0).UTC()
	}
	return time.Now().UTC()
}
