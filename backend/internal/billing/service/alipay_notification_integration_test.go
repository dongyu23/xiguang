package service

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/infra/config"
	infraDB "xiguang/backend/internal/infra/db"
)

func serviceIntegrationRepo(t *testing.T) (*repository.PG, *pgxpool.Pool, int64) {
	t.Helper()
	dsn := os.Getenv("BILLING_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("BILLING_TEST_DATABASE_URL is not configured")
	}
	pool, err := infraDB.Connect(t.Context(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	var userID int64
	err = pool.QueryRow(t.Context(), `INSERT INTO users(username,password_hash,nickname) VALUES($1,'test','billing') RETURNING id`,
		fmt.Sprintf("billing_service_it_%d", time.Now().UnixNano())).Scan(&userID)
	if err != nil {
		pool.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, userID)
		pool.Close()
	})
	return repository.NewPG(pool), pool, userID
}

func signAlipayNotification(t *testing.T, provider *AlipayProvider, values url.Values) {
	t.Helper()
	values.Set("sign_type", "RSA2")
	unsigned := make(url.Values, len(values))
	for key, value := range values {
		if key != "sign" && key != "sign_type" && len(value) > 0 && value[0] != "" {
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
}

func TestAlipaySignedNotificationsCompleteMonthlyPaymentAndHandleOutOfOrderRefund(t *testing.T) {
	repo, pool, userID := serviceIntegrationRepo(t)
	provider := testAlipayProvider(t)
	paymentService := New(repo, config.Config{
		PaymentChannels:      []string{"alipay"},
		PaymentEncryptionKey: "01234567890123456789012345678901",
		AlipayAppID:          provider.cfg.AlipayAppID,
	}, provider)
	paymentService.initialized.Store(true)
	product, err := repo.ProductByCode(t.Context(), "starlight_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	order, err := repo.CreatePendingOrder(t.Context(), userID, product, "alipay", fmt.Sprintf("signed-callback-%d", time.Now().UnixNano()))
	if err != nil {
		t.Fatal(err)
	}
	prefix := fmt.Sprintf("alipay-it-%d", time.Now().UnixNano())
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM payment_events WHERE provider='alipay' AND external_event_id LIKE $1`, prefix+"%")
		_, _ = pool.Exec(context.Background(), `DELETE FROM pending_payment_refunds WHERE provider='alipay' AND transaction_id LIKE $1`, prefix+"%")
	})
	now := time.Now().UTC().Truncate(time.Second)
	agreementID := prefix + "-agreement"
	agreement := url.Values{
		"app_id":                {provider.cfg.AlipayAppID},
		"notify_id":             {prefix + "-agreement-event"},
		"notify_type":           {"agreement_status_sync"},
		"agreement_no":          {agreementID},
		"external_agreement_no": {order.PublicID},
		"alipay_user_id":        {prefix + "-payer"},
		"status":                {"NORMAL"},
		"sign_time":             {now.Format("2006-01-02 15:04:05")},
		"notify_time":           {now.Format("2006-01-02 15:04:05")},
	}
	signAlipayNotification(t, provider, agreement)
	processed, err := paymentService.ProcessAlipayNotification(t.Context(), agreement)
	if err != nil || !processed {
		t.Fatalf("agreement notification = %v, %v", processed, err)
	}

	tradeID := prefix + "-first-trade"
	trade := url.Values{
		"app_id":       {provider.cfg.AlipayAppID},
		"notify_id":    {prefix + "-trade-event"},
		"notify_type":  {"trade_status_sync"},
		"agreement_no": {agreementID},
		"trade_no":     {tradeID},
		"trade_status": {"TRADE_SUCCESS"},
		"total_amount": {"12.01"},
		"gmt_payment":  {now.Format("2006-01-02 15:04:05")},
		"notify_time":  {now.Format("2006-01-02 15:04:05")},
	}
	signAlipayNotification(t, provider, trade)
	processed, err = paymentService.ProcessAlipayNotification(t.Context(), trade)
	if processed || !errors.Is(err, ErrBadRequest) {
		t.Fatalf("mismatched amount notification = %v, %v", processed, err)
	}
	trade.Set("total_amount", "12.00")
	signAlipayNotification(t, provider, trade)
	processed, err = paymentService.ProcessAlipayNotification(t.Context(), trade)
	if err != nil || !processed {
		t.Fatalf("corrected trade notification = %v, %v", processed, err)
	}
	entitlement, err := repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "starlight" || entitlement.Status != "active" {
		t.Fatalf("monthly first charge did not grant entitlement: %+v, %v", entitlement, err)
	}
	var periodEndBefore time.Time
	if err = pool.QueryRow(t.Context(), `SELECT current_period_end FROM subscriptions WHERE user_id=$1`, userID).Scan(&periodEndBefore); err != nil {
		t.Fatal(err)
	}
	processed, err = paymentService.ProcessAlipayNotification(t.Context(), trade)
	if err != nil || processed {
		t.Fatalf("trade replay = %v, %v", processed, err)
	}
	var periodEndAfter time.Time
	if err = pool.QueryRow(t.Context(), `SELECT current_period_end FROM subscriptions WHERE user_id=$1`, userID).Scan(&periodEndAfter); err != nil {
		t.Fatal(err)
	}
	if !periodEndAfter.Equal(periodEndBefore) {
		t.Fatalf("trade replay advanced period twice: %s -> %s", periodEndBefore, periodEndAfter)
	}

	futureTradeID := prefix + "-future-trade"
	refund := url.Values{
		"app_id":      {provider.cfg.AlipayAppID},
		"notify_id":   {prefix + "-refund-event"},
		"notify_type": {"trade_refund"},
		"trade_no":    {futureTradeID},
		"refund_fee":  {"12.00"},
		"gmt_refund":  {now.Add(time.Minute).Format("2006-01-02 15:04:05")},
		"notify_time": {now.Add(time.Minute).Format("2006-01-02 15:04:05")},
	}
	signAlipayNotification(t, provider, refund)
	processed, err = paymentService.ProcessAlipayNotification(t.Context(), refund)
	if err != nil || !processed {
		t.Fatalf("early refund notification = %v, %v", processed, err)
	}
	futureTrade := url.Values{
		"app_id":       {provider.cfg.AlipayAppID},
		"notify_id":    {prefix + "-future-trade-event"},
		"notify_type":  {"trade_status_sync"},
		"agreement_no": {agreementID},
		"trade_no":     {futureTradeID},
		"trade_status": {"TRADE_SUCCESS"},
		"total_amount": {"12.00"},
		"gmt_payment":  {now.Add(2 * time.Minute).Format("2006-01-02 15:04:05")},
		"notify_time":  {now.Add(2 * time.Minute).Format("2006-01-02 15:04:05")},
	}
	signAlipayNotification(t, provider, futureTrade)
	processed, err = paymentService.ProcessAlipayNotification(t.Context(), futureTrade)
	if err != nil || !processed {
		t.Fatalf("trade following early refund = %v, %v", processed, err)
	}
	entitlement, err = repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "glimmer" || entitlement.Status != "revoked" {
		t.Fatalf("out-of-order refund did not revoke entitlement: %+v, %v", entitlement, err)
	}
}
