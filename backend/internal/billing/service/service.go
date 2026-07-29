package service

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/infra/config"
)

var (
	ErrDisabled           = errors.New("payments_disabled")
	ErrChannelUnavailable = errors.New("payment_channel_unavailable")
	ErrBadRequest         = errors.New("invalid_payment_request")
)

type Service struct {
	repo                   *repository.PG
	cfg                    config.Config
	providers              map[string]DirectDebitProvider
	metrics                *billingMetrics
	appleConnectBaseURL    string
	appleConnectHTTPClient *http.Client
	appleJWSRoots          *x509.CertPool
	initialized            atomic.Bool
}

var ErrStorageQuota = repository.ErrStorageQuota

func New(repo *repository.PG, cfg config.Config, providers ...DirectDebitProvider) *Service {
	if len(providers) == 0 {
		for _, channel := range cfg.PaymentChannels {
			switch channel {
			case "alipay":
				providers = append(providers, NewAlipayProvider(cfg))
			case "wechat":
				providers = append(providers, NewWeChatProvider(cfg))
			}
		}
	}
	byName := make(map[string]DirectDebitProvider, len(providers))
	for _, provider := range providers {
		if provider != nil {
			byName[strings.ToLower(provider.Name())] = provider
		}
	}
	service := &Service{
		repo:                   repo,
		cfg:                    cfg,
		providers:              byName,
		metrics:                newBillingMetrics(),
		appleConnectBaseURL:    "https://api.appstoreconnect.apple.com",
		appleConnectHTTPClient: &http.Client{Timeout: 20 * time.Second},
	}
	if !cfg.PaymentEnabled {
		service.initialized.Store(true)
	}
	return service
}

func (s *Service) PrepareInitialization(ctx context.Context) error {
	if !s.cfg.PaymentEnabled {
		s.initialized.Store(true)
		return nil
	}
	s.initialized.Store(false)
	for _, channel := range s.cfg.PaymentChannels {
		if err := s.repo.MarkProviderProductsVerified(ctx, channel, nil); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) Catalog(ctx context.Context, provider string) ([]domain.Product, error) {
	if provider == "" {
		provider = "apple"
	}
	items, err := s.repo.Catalog(ctx, provider)
	if err != nil {
		return nil, err
	}
	if !s.cfg.PaymentEnabled || !s.channelEnabled(provider) || !s.initialized.Load() {
		for index := range items {
			items[index].ProviderEnabled = false
		}
	}
	return items, nil
}
func (s *Service) Entitlement(ctx context.Context, userID int64) (domain.Entitlement, error) {
	entitlement, err := s.repo.Entitlement(ctx, userID)
	if err != nil {
		s.metrics.inc("xiguang_payment_entitlement_reads_total", labels("result", "failed"))
		return entitlement, err
	}
	s.metrics.inc("xiguang_payment_entitlement_reads_total", labels("result", "success"))
	snapshot, publicKey, err := s.signOfflineEntitlement(userID, entitlement)
	if err != nil {
		return entitlement, err
	}
	entitlement.OfflineSnapshot = snapshot
	entitlement.OfflinePublicKey = publicKey
	return entitlement, nil
}

func (s *Service) signOfflineEntitlement(userID int64, entitlement domain.Entitlement) (string, string, error) {
	secret := s.cfg.PaymentEncryptionKey
	if secret == "" {
		secret = s.cfg.JWTSecret
	}
	seed := sha256.Sum256([]byte("xiguang:offline-entitlement:" + secret))
	privateKey := ed25519.NewKeyFromSeed(seed[:])
	publicKey := privateKey.Public().(ed25519.PublicKey)
	now := time.Now().UTC()
	header, _ := json.Marshal(map[string]string{"alg": "EdDSA", "typ": "XG-ENT"})
	payload, err := json.Marshal(map[string]any{
		"sub":                  userID,
		"iat":                  now.Unix(),
		"exp":                  now.Add(72 * time.Hour).Unix(),
		"tier":                 entitlement.Tier,
		"status":               entitlement.Status,
		"provider":             entitlement.Provider,
		"product_code":         entitlement.ProductCode,
		"subscription_id":      entitlement.SubscriptionID,
		"valid_until":          entitlement.ValidUntil,
		"grace_until":          entitlement.GraceUntil,
		"cancel_at_period_end": entitlement.CancelAtPeriodEnd,
		"storage_quota_bytes":  entitlement.StorageQuotaBytes,
		"storage_used_bytes":   entitlement.StorageUsedBytes,
		"ai_quota":             entitlement.AIQuota,
		"ai_used":              entitlement.AIUsed,
		"version":              entitlement.EntitlementVersion,
	})
	if err != nil {
		return "", "", err
	}
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	signature := ed25519.Sign(privateKey, []byte(unsigned))
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature), base64.RawURLEncoding.EncodeToString(publicKey), nil
}
func (s *Service) ReserveStorage(ctx context.Context, userID int64, objectKey string, bytes int64) error {
	return s.repo.ReserveStorage(ctx, userID, objectKey, bytes)
}

func (s *Service) ReserveStorageFor(ctx context.Context, userID int64, objectKey string, bytes int64, ttl time.Duration) error {
	return s.repo.ReserveStorageFor(ctx, userID, objectKey, bytes, ttl)
}
func (s *Service) ConsumeStorage(ctx context.Context, userID int64, objectKey string) error {
	return s.repo.ConsumeStorage(ctx, userID, objectKey)
}
func (s *Service) ReleaseStorage(ctx context.Context, userID int64, objectKey string) {
	s.repo.ReleaseStorage(ctx, userID, objectKey)
}
func (s *Service) ReserveAI(ctx context.Context, userID int64) error {
	return s.repo.ReserveAI(ctx, userID)
}
func (s *Service) ReleaseAI(ctx context.Context, userID int64) { s.repo.ReleaseAI(ctx, userID) }
func (s *Service) Order(ctx context.Context, userID int64, id string) (domain.Order, error) {
	return s.repo.Order(ctx, userID, id)
}

func (s *Service) CreateSubscription(ctx context.Context, userID int64, req domain.CreateSubscriptionRequest) (domain.CreateSubscriptionResult, error) {
	if !s.cfg.PaymentEnabled {
		return domain.CreateSubscriptionResult{}, ErrDisabled
	}
	if !s.initialized.Load() {
		return domain.CreateSubscriptionResult{}, ErrChannelUnavailable
	}
	if req.ClientRequestID == "" || !s.channelEnabled(req.Provider) || req.Provider == "apple" {
		return domain.CreateSubscriptionResult{}, ErrBadRequest
	}
	p, err := s.repo.ProductByCode(ctx, req.ProductCode, req.Provider)
	if err != nil {
		return domain.CreateSubscriptionResult{}, err
	}
	if !p.ProviderEnabled {
		return domain.CreateSubscriptionResult{}, ErrChannelUnavailable
	}
	provider := s.providers[req.Provider]
	if provider == nil {
		return domain.CreateSubscriptionResult{}, ErrChannelUnavailable
	}
	o, err := s.repo.CreatePendingOrder(ctx, userID, p, req.Provider, req.ClientRequestID)
	if err != nil {
		s.metrics.inc("xiguang_payment_order_events_total", labels("provider", req.Provider, "status", "failed"))
		return domain.CreateSubscriptionResult{}, err
	}
	s.metrics.inc("xiguang_payment_order_events_total", labels("provider", req.Provider, "status", "created"))
	payload, err := provider.StartAgreement(ctx, o, p)
	if err != nil {
		s.metrics.inc("xiguang_payment_order_events_total", labels("provider", req.Provider, "status", "failed"))
		if markErr := s.repo.FailOrder(ctx, userID, o.PublicID, "agreement_start_failed"); markErr != nil {
			return domain.CreateSubscriptionResult{}, errors.Join(err, markErr)
		}
		return domain.CreateSubscriptionResult{}, err
	}
	s.metrics.inc("xiguang_payment_order_events_total", labels("provider", req.Provider, "status", "pending"))
	payload["order_id"] = o.PublicID
	payload["provider"] = req.Provider
	return domain.CreateSubscriptionResult{Order: o, SDKPayload: payload}, nil
}

func (s *Service) VerifyApple(ctx context.Context, userID int64, signed string) (domain.Order, error) {
	if !s.cfg.PaymentEnabled || !s.channelEnabled("apple") {
		return domain.Order{}, ErrDisabled
	}
	if !s.initialized.Load() {
		return domain.Order{}, ErrChannelUnavailable
	}
	env := map[bool]string{true: "Production", false: "Sandbox"}[s.cfg.PaymentEnvironment == "production"]
	t, err := verifyAppleTransactionWithRoots(signed, s.cfg.AppleBundleID, env, s.appleJWSRoots)
	if err != nil {
		s.metrics.inc("xiguang_payment_signature_failures_total", labels("provider", "apple"))
		return domain.Order{}, err
	}
	var ownerID int64
	if t.AppAccountToken != "" {
		ownerID, err = s.repo.UserIDByPublicID(ctx, t.AppAccountToken)
	} else {
		ownerID, err = s.repo.UserIDByAppleSubscription(ctx, t.OriginalTransactionID)
	}
	if err != nil || ownerID != userID {
		return domain.Order{}, ErrInvalidAppleTransaction
	}
	p, err := s.repo.ProductByExternalID(ctx, "apple", t.ProductID)
	if err != nil || !p.ProviderEnabled {
		return domain.Order{}, ErrChannelUnavailable
	}
	order, err := s.repo.ApplyAppleTransaction(ctx, userID, p, t)
	if err == nil {
		s.metrics.inc("xiguang_payment_order_events_total", labels("provider", "apple", "status", "paid"))
	}
	return order, err
}

func (s *Service) RestoreApple(ctx context.Context, userID int64, transactions []string) (domain.Entitlement, error) {
	if len(transactions) == 0 || len(transactions) > 100 {
		return domain.Entitlement{}, ErrBadRequest
	}
	for _, signed := range transactions {
		if _, err := s.VerifyApple(ctx, userID, signed); err != nil {
			return domain.Entitlement{}, err
		}
	}
	return s.repo.Entitlement(ctx, userID)
}

func (s *Service) Cancel(ctx context.Context, userID int64, id string) (bool, error) {
	subscription, err := s.repo.Subscription(ctx, userID, id)
	if errors.Is(err, repository.ErrNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if subscription.Provider != "apple" {
		provider := s.providers[subscription.Provider]
		if provider == nil || subscription.ExternalSubscriptionID == "" {
			return false, ErrChannelUnavailable
		}
		if err = provider.Cancel(ctx, subscription.ExternalSubscriptionID); err != nil {
			return false, err
		}
	}
	return s.repo.Cancel(ctx, userID, id)
}

func (s *Service) Readiness(ctx context.Context) domain.Readiness {
	r := domain.Readiness{Enabled: s.cfg.PaymentEnabled, Ready: true, Mode: s.cfg.PaymentEnvironment, Catalog: "configured", Channels: map[string]string{}}
	products, err := s.repo.Catalog(ctx, "apple")
	if err != nil {
		r.Catalog = "database_error"
		r.Ready = false
	} else {
		r.Catalog = validateCatalogStructure("apple", products)
		if r.Catalog != "configured" {
			r.Ready = false
		}
	}
	if !s.cfg.PaymentEnabled {
		return r
	}
	if !s.initialized.Load() {
		r.Ready = false
	}
	for _, channel := range s.cfg.PaymentChannels {
		status := "configured"
		products, err := s.repo.Catalog(ctx, channel)
		if err != nil {
			status = "database_error"
			r.Ready = false
		} else {
			status = validateConfiguredCatalog(channel, products)
			if status != "configured" {
				r.Ready = false
			}
		}
		if status == "configured" && !s.initialized.Load() {
			status = "initializing"
			r.Ready = false
		}
		r.Channels[channel] = status
	}
	return r
}

func (s *Service) RecordWebhook(ctx context.Context, provider, eventID, eventType string, payload []byte) (bool, error) {
	if !s.channelEnabled(provider) || eventID == "" || len(payload) == 0 {
		return false, ErrBadRequest
	}
	encrypted, hash, err := encryptPayload(s.cfg.PaymentEncryptionKey, payload)
	if err != nil {
		return false, err
	}
	return s.repo.RecordEvent(ctx, provider, eventID, eventType, encrypted, hash)
}

func (s *Service) ProcessAppleNotification(ctx context.Context, signedPayload string) (bool, error) {
	payload, err := verifyAppleJWSWithRoots(signedPayload, s.appleJWSRoots)
	if err != nil {
		return false, err
	}
	var notification struct {
		NotificationUUID string `json:"notificationUUID"`
		NotificationType string `json:"notificationType"`
		SignedDate       int64  `json:"signedDate"`
		Data             struct {
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			SignedRenewalInfo     string `json:"signedRenewalInfo"`
		} `json:"data"`
	}
	if json.Unmarshal(payload, &notification) != nil || notification.NotificationUUID == "" || notification.Data.SignedTransactionInfo == "" {
		return false, ErrBadRequest
	}
	inserted, err := s.RecordWebhook(ctx, "apple", notification.NotificationUUID, notification.NotificationType, []byte(signedPayload))
	if err != nil || !inserted {
		result := "duplicate"
		if err != nil {
			result = "failed"
		}
		s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "apple", "result", result))
		return inserted, err
	}
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "apple", "result", "received"))
	if notification.SignedDate > 0 {
		s.metrics.observeWebhook("apple", time.Since(time.UnixMilli(notification.SignedDate)))
	}
	env := map[bool]string{true: "Production", false: "Sandbox"}[s.cfg.PaymentEnvironment == "production"]
	t, err := verifyAppleTransactionWithRoots(notification.Data.SignedTransactionInfo, s.cfg.AppleBundleID, env, s.appleJWSRoots)
	if err != nil {
		s.metrics.inc("xiguang_payment_signature_failures_total", labels("provider", "apple"))
		_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "failed", ChannelError(err))
		return false, err
	}
	var userID int64
	if t.AppAccountToken != "" {
		userID, err = s.repo.UserIDByPublicID(ctx, t.AppAccountToken)
	} else {
		userID, err = s.repo.UserIDByAppleSubscription(ctx, t.OriginalTransactionID)
	}
	if err != nil {
		_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "failed", "account_not_found")
		return false, err
	}
	p, err := s.repo.ProductByExternalID(ctx, "apple", t.ProductID)
	if err == nil && !p.ProviderEnabled {
		err = ErrChannelUnavailable
	}
	if err == nil {
		_, err = s.repo.ApplyAppleTransaction(ctx, userID, p, t)
	}
	if err != nil {
		_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "failed", ChannelError(err))
		return false, err
	}
	if notification.Data.SignedRenewalInfo != "" {
		renewal, renewalErr := verifyAppleRenewalInfoWithRoots(notification.Data.SignedRenewalInfo, s.cfg.AppleBundleID, env, s.appleJWSRoots)
		if renewalErr != nil || renewal.OriginalTransactionID != t.OriginalTransactionID {
			_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "failed", "invalid_renewal_info")
			return false, ErrInvalidAppleTransaction
		}
		if renewalErr = s.repo.SetAppleCancelAtPeriodEnd(ctx, userID, renewal.OriginalTransactionID, renewal.AutoRenewStatus == 0); renewalErr != nil {
			_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "failed", ChannelError(renewalErr))
			return false, renewalErr
		}
	}
	_ = s.repo.MarkEvent(ctx, "apple", notification.NotificationUUID, "processed", "")
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "apple", "result", "processed"))
	return true, nil
}

func (s *Service) ProcessAlipayNotification(ctx context.Context, values url.Values) (bool, error) {
	provider, ok := s.providers["alipay"].(*AlipayProvider)
	if !ok || !s.channelEnabled("alipay") {
		return false, ErrChannelUnavailable
	}
	if values.Get("app_id") != s.cfg.AlipayAppID || values.Get("notify_id") == "" {
		return false, ErrBadRequest
	}
	if err := provider.VerifyNotification(values); err != nil {
		s.metrics.inc("xiguang_payment_signature_failures_total", labels("provider", "alipay"))
		return false, err
	}
	payload := []byte(values.Encode())
	eventType := values.Get("notify_type")
	if eventType == "" {
		eventType = values.Get("trade_status")
	}
	inserted, err := s.RecordWebhook(ctx, "alipay", values.Get("notify_id"), eventType, payload)
	if err != nil || !inserted {
		result := "duplicate"
		if err != nil {
			result = "failed"
		}
		s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "alipay", "result", result))
		return inserted, err
	}
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "alipay", "result", "received"))
	if notifiedAt := parseAlipayTime(values.Get("notify_time")); !notifiedAt.IsZero() {
		s.metrics.observeWebhook("alipay", time.Since(notifiedAt))
	}
	markFailed := func(processErr error) (bool, error) {
		_ = s.repo.MarkEvent(ctx, "alipay", values.Get("notify_id"), "failed", ChannelError(processErr))
		return false, processErr
	}

	agreementID := values.Get("agreement_no")
	externalAgreementID := values.Get("external_agreement_no")
	payerSubject := values.Get("alipay_user_id")
	if payerSubject == "" {
		payerSubject = values.Get("buyer_id")
	}
	agreementStatus := strings.ToUpper(values.Get("status"))
	if agreementID != "" && externalAgreementID != "" && (agreementStatus == "NORMAL" || agreementStatus == "SIGNED") {
		signedAt := parseAlipayTime(values.Get("sign_time"))
		if err = s.repo.ActivateAgreement(ctx, "alipay", externalAgreementID, agreementID, payerHash("alipay", payerSubject), signedAt); err != nil {
			return markFailed(err)
		}
	}
	if agreementID != "" && (agreementStatus == "STOP" || agreementStatus == "UNSIGN") {
		if err = s.repo.CancelProviderAgreement(ctx, "alipay", agreementID); err != nil {
			return markFailed(err)
		}
	}
	tradeStatus := strings.ToUpper(values.Get("trade_status"))
	if values.Get("trade_no") != "" && (tradeStatus == "TRADE_SUCCESS" || tradeStatus == "TRADE_FINISHED") {
		if agreementID == "" {
			return markFailed(ErrBadRequest)
		}
		candidate, findErr := s.repo.RenewalByAgreement(ctx, "alipay", agreementID)
		if findErr != nil {
			return markFailed(findErr)
		}
		amountCents, amountErr := parseCNYCents(values.Get("total_amount"))
		if amountErr != nil || amountCents != candidate.Product.PriceCents {
			return markFailed(ErrBadRequest)
		}
		paidAt := parseAlipayTime(values.Get("gmt_payment"))
		if paidAt.IsZero() {
			paidAt = parseAlipayTime(values.Get("notify_time"))
		}
		if paidAt.IsZero() {
			paidAt = time.Now().UTC()
		}
		if err = s.repo.CompleteRenewal(ctx, candidate, values.Get("trade_no"), paidAt.UTC()); err != nil {
			return markFailed(err)
		}
	}
	if values.Get("trade_no") != "" && values.Get("refund_fee") != "" {
		if err = s.repo.RevokeProviderTransaction(ctx, "alipay", values.Get("trade_no"), parseAlipayTime(values.Get("gmt_refund"))); err != nil {
			return markFailed(err)
		}
	}
	_ = s.repo.MarkEvent(ctx, "alipay", values.Get("notify_id"), "processed", "")
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "alipay", "result", "processed"))
	return true, nil
}

func parseCNYCents(value string) (int, error) {
	value = strings.TrimSpace(value)
	parts := strings.Split(value, ".")
	if len(parts) > 2 || len(parts) == 0 || parts[0] == "" {
		return 0, ErrBadRequest
	}
	yuan, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || yuan < 0 {
		return 0, ErrBadRequest
	}
	fraction := ""
	if len(parts) == 2 {
		fraction = parts[1]
	}
	if len(fraction) > 2 {
		return 0, ErrBadRequest
	}
	for len(fraction) < 2 {
		fraction += "0"
	}
	fen := int64(0)
	if fraction != "" {
		fen, err = strconv.ParseInt(fraction, 10, 64)
		if err != nil {
			return 0, ErrBadRequest
		}
	}
	if yuan > (int64(^uint(0)>>1)-fen)/100 {
		return 0, ErrBadRequest
	}
	return int(yuan*100 + fen), nil
}

func (s *Service) ProcessWeChatNotification(ctx context.Context, request *http.Request) (bool, error) {
	provider, ok := s.providers["wechat"].(*WeChatProvider)
	if !ok || !s.channelEnabled("wechat") {
		return false, ErrChannelUnavailable
	}
	raw, err := io.ReadAll(io.LimitReader(request.Body, (1<<20)+1))
	if err != nil || len(raw) > 1<<20 {
		return false, ErrBadRequest
	}
	request.Body = io.NopCloser(strings.NewReader(string(raw)))
	var content struct {
		MchID           string `json:"mchid"`
		AppID           string `json:"appid"`
		OutContractCode string `json:"out_contract_code"`
		ContractID      string `json:"contract_id"`
		ContractState   string `json:"contract_state"`
		ContractStatus  string `json:"contract_status"`
		OutTradeNo      string `json:"out_trade_no"`
		TransactionID   string `json:"transaction_id"`
		TradeState      string `json:"trade_state"`
		SuccessTime     string `json:"success_time"`
		RefundStatus    string `json:"refund_status"`
		OpenID          string `json:"openid"`
		Amount          struct {
			Total    int    `json:"total"`
			Currency string `json:"currency"`
		} `json:"amount"`
	}
	notification, err := provider.ParseNotification(ctx, request, &content)
	if err != nil {
		s.metrics.inc("xiguang_payment_signature_failures_total", labels("provider", "wechat"))
		return false, err
	}
	if notification.ID == "" || content.MchID != s.cfg.WeChatPayMerchantID || content.AppID != s.cfg.WeChatPayAppID {
		return false, ErrBadRequest
	}
	inserted, err := s.RecordWebhook(ctx, "wechat", notification.ID, notification.EventType, raw)
	if err != nil || !inserted {
		result := "duplicate"
		if err != nil {
			result = "failed"
		}
		s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "wechat", "result", result))
		return inserted, err
	}
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "wechat", "result", "received"))
	if notification.CreateTime != nil {
		s.metrics.observeWebhook("wechat", time.Since(notification.CreateTime.UTC()))
	}
	markFailed := func(processErr error) (bool, error) {
		_ = s.repo.MarkEvent(ctx, "wechat", notification.ID, "failed", ChannelError(processErr))
		return false, processErr
	}

	contractState := strings.ToUpper(content.ContractState)
	if contractState == "" {
		contractState = strings.ToUpper(content.ContractStatus)
	}
	if content.ContractID != "" && content.OutContractCode != "" && (contractState == "NORMAL" || contractState == "SIGNED") {
		signedAt := time.Now().UTC()
		if notification.CreateTime != nil {
			signedAt = notification.CreateTime.UTC()
		}
		if err = s.repo.ActivateAgreement(ctx, "wechat", content.OutContractCode, content.ContractID, payerHash("wechat", content.OpenID), signedAt); err != nil {
			return markFailed(err)
		}
	}
	if content.ContractID != "" && (contractState == "TERMINATED" || contractState == "STOP" || contractState == "CANCELED") {
		if err = s.repo.CancelProviderAgreement(ctx, "wechat", content.ContractID); err != nil {
			return markFailed(err)
		}
	}
	if content.TransactionID != "" && strings.ToUpper(content.TradeState) == "SUCCESS" && content.ContractID != "" {
		candidate, findErr := s.repo.RenewalByAgreement(ctx, "wechat", content.ContractID)
		if findErr != nil {
			return markFailed(findErr)
		}
		if content.Amount.Total != candidate.Product.PriceCents || content.Amount.Currency != candidate.Product.Currency {
			return markFailed(ErrBadRequest)
		}
		paidAt, parseErr := time.Parse(time.RFC3339, content.SuccessTime)
		if parseErr != nil {
			paidAt = time.Now().UTC()
		}
		if err = s.repo.CompleteRenewal(ctx, candidate, content.TransactionID, paidAt.UTC()); err != nil {
			return markFailed(err)
		}
	}
	if content.TransactionID != "" && strings.ToUpper(content.RefundStatus) == "SUCCESS" {
		if err = s.repo.RevokeProviderTransaction(ctx, "wechat", content.TransactionID, time.Now().UTC()); err != nil {
			return markFailed(err)
		}
	}
	_ = s.repo.MarkEvent(ctx, "wechat", notification.ID, "processed", "")
	s.metrics.inc("xiguang_payment_webhook_events_total", labels("provider", "wechat", "result", "processed"))
	return true, nil
}

func payerHash(provider, subject string) string {
	if strings.TrimSpace(subject) == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(provider + ":" + subject))
	return hex.EncodeToString(sum[:])
}

func (s *Service) channelEnabled(provider string) bool {
	for _, v := range s.cfg.PaymentChannels {
		if v == strings.ToLower(provider) {
			return true
		}
	}
	return false
}

func encryptPayload(secret string, payload []byte) ([]byte, string, error) {
	key := sha256.Sum256([]byte(secret))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return nil, "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, "", err
	}
	encrypted := gcm.Seal(nonce, nonce, payload, nil)
	h := sha256.Sum256(payload)
	return encrypted, hex.EncodeToString(h[:]), nil
}

func ChannelError(err error) string {
	if err == nil {
		return ""
	}
	if errors.Is(err, ErrDisabled) {
		return "payments_disabled"
	}
	if errors.Is(err, ErrChannelUnavailable) {
		return "channel_not_ready"
	}
	if errors.Is(err, ErrBadRequest) {
		return "invalid_payment_request"
	}
	if errors.Is(err, ErrInvalidAppleTransaction) {
		return "invalid_apple_transaction"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "provider_timeout"
	}
	if errors.Is(err, context.Canceled) {
		return "provider_canceled"
	}
	if errors.Is(err, repository.ErrActiveSubscription) {
		return "active_subscription_exists"
	}
	if errors.Is(err, repository.ErrProductUnavailable) {
		return "product_unavailable"
	}
	if errors.Is(err, repository.ErrTransactionOwner) {
		return "transaction_owner_mismatch"
	}
	message := strings.ToLower(err.Error())
	if strings.Contains(message, "signature") || strings.Contains(message, "certificate") ||
		strings.Contains(message, "private key") || strings.Contains(message, "credential") {
		return "provider_auth_failed"
	}
	if strings.Contains(message, "http") || strings.Contains(message, "status code") {
		return "provider_http_error"
	}
	return "provider_error"
}

func (s *Service) Run(ctx context.Context) {
	sweepTicker := time.NewTicker(time.Minute)
	reconcileTicker := time.NewTicker(24 * time.Hour)
	defer sweepTicker.Stop()
	defer reconcileTicker.Stop()
	if s.cfg.PaymentEnabled {
		for !s.initialized.Load() {
			initializeCtx, cancel := context.WithTimeout(ctx, 3*time.Minute)
			err := s.Initialize(initializeCtx)
			cancel()
			if err == nil {
				break
			}
			s.metrics.inc("xiguang_payment_initialization_total", labels("result", "failed"))
			select {
			case <-ctx.Done():
				return
			case <-time.After(15 * time.Second):
			}
		}
		s.metrics.inc("xiguang_payment_initialization_total", labels("result", "ready"))
	}

	if s.cfg.PaymentEnabled && s.channelEnabled("apple") {
		reconcileCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
		_ = s.ReconcileApple(reconcileCtx)
		cancel()
	}
	if s.cfg.PaymentEnabled && len(s.providers) > 0 {
		reconcileCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
		_ = s.ReconcileDirect(reconcileCtx)
		cancel()
	}
	for {
		select {
		case <-ctx.Done():
			return
		case <-sweepTicker.C:
			_ = s.repo.Sweep(ctx)
			if s.cfg.PaymentEnabled {
				renewCtx, cancel := context.WithTimeout(ctx, 50*time.Second)
				_ = s.RunDirectRenewals(renewCtx)
				cancel()
			}
		case <-reconcileTicker.C:
			reconcileCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
			_ = s.ReconcileApple(reconcileCtx)
			_ = s.ReconcileDirect(reconcileCtx)
			cancel()
		}
	}
}
