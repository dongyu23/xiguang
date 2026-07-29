package service

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"testing"
	"time"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/billing/repository"
	"xiguang/backend/internal/infra/config"
)

type appleSmokeSigner struct {
	key      *ecdsa.PrivateKey
	header   string
	rootPool *x509.CertPool
}

func newAppleSmokeSigner(t *testing.T) appleSmokeSigner {
	t.Helper()
	now := time.Now()
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	rootTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(101), Subject: pkix.Name{CommonName: "Apple smoke root"},
		NotBefore: now.Add(-time.Hour), NotAfter: now.Add(24 * time.Hour), IsCA: true, BasicConstraintsValid: true,
		KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	rootCert, err := x509.ParseCertificate(rootDER)
	if err != nil {
		t.Fatal(err)
	}
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	leafTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(102), Subject: pkix.Name{CommonName: "Apple smoke signing"},
		NotBefore: now.Add(-time.Hour), NotAfter: now.Add(24 * time.Hour), KeyUsage: x509.KeyUsageDigitalSignature,
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTemplate, rootCert, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	header, _ := json.Marshal(map[string]any{
		"alg": "ES256", "x5c": []string{base64.StdEncoding.EncodeToString(leafDER), base64.StdEncoding.EncodeToString(rootDER)},
	})
	roots := x509.NewCertPool()
	roots.AddCert(rootCert)
	return appleSmokeSigner{key: leafKey, header: base64.RawURLEncoding.EncodeToString(header), rootPool: roots}
}

func (s appleSmokeSigner) sign(t *testing.T, payload any) string {
	t.Helper()
	encodedPayload, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	unsigned := s.header + "." + base64.RawURLEncoding.EncodeToString(encodedPayload)
	digest := sha256.Sum256([]byte(unsigned))
	r, signatureS, err := ecdsa.Sign(rand.Reader, s.key, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	signature := append(padBigInt(r, 32), padBigInt(signatureS, 32)...)
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func TestAppleSimulatedPurchaseRestoreRenewCancelRefundAndCrossChannelProtection(t *testing.T) {
	repo, pool, userID := serviceIntegrationRepo(t)
	const productID = "com.xiguang.membership.starlight.year"
	var wasEnabled bool
	if err := pool.QueryRow(t.Context(), `SELECT enabled FROM billing_provider_products WHERE provider='apple' AND external_product_id=$1`, productID).Scan(&wasEnabled); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now() WHERE provider='apple' AND external_product_id=$1`, productID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=$2 WHERE provider='apple' AND external_product_id=$1`, productID, wasEnabled)
	})
	var accountToken string
	if err := pool.QueryRow(t.Context(), `SELECT public_id::text FROM users WHERE id=$1`, userID).Scan(&accountToken); err != nil {
		t.Fatal(err)
	}
	signer := newAppleSmokeSigner(t)
	paymentService := New(repo, config.Config{
		PaymentEnabled:       true,
		PaymentEnvironment:   "sandbox",
		PaymentChannels:      []string{"apple", "alipay"},
		PaymentEncryptionKey: "01234567890123456789012345678901",
		AppleBundleID:        "com.xiguang.xiguang",
	})
	paymentService.initialized.Store(true)
	paymentService.appleJWSRoots = signer.rootPool
	prefix := fmt.Sprintf("apple-smoke-%d", time.Now().UnixNano())
	t.Cleanup(func() {
		_, _ = pool.Exec(t.Context(), `DELETE FROM payment_events WHERE provider='apple' AND external_event_id LIKE $1`, prefix+"%")
	})
	now := time.Now().UTC().Truncate(time.Millisecond)
	originalID := prefix + "-original"
	trial := signer.sign(t, map[string]any{
		"transactionId": prefix + "-trial", "originalTransactionId": originalID, "productId": productID,
		"bundleId": "com.xiguang.xiguang", "environment": "Sandbox", "appAccountToken": accountToken,
		"purchaseDate": now.UnixMilli(), "expiresDate": now.Add(7 * 24 * time.Hour).UnixMilli(), "offerType": 1,
	})
	order, err := paymentService.VerifyApple(t.Context(), userID, trial)
	if err != nil || order.Status != "paid" {
		t.Fatalf("Apple trial purchase = %+v, %v", order, err)
	}
	entitlement, err := repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "starlight" || entitlement.Status != "trialing" {
		t.Fatalf("Apple trial entitlement = %+v, %v", entitlement, err)
	}
	if _, err = paymentService.RestoreApple(t.Context(), userID, []string{trial}); err != nil {
		t.Fatalf("Apple cross-device restore failed: %v", err)
	}
	var otherUserID int64
	if err = pool.QueryRow(t.Context(), `INSERT INTO users(username,password_hash,nickname) VALUES($1,'test','other') RETURNING id`,
		prefix+"-other-user").Scan(&otherUserID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, otherUserID)
	})
	if _, err = paymentService.RestoreApple(t.Context(), otherUserID, []string{trial}); !errors.Is(err, ErrInvalidAppleTransaction) {
		t.Fatalf("another account restored owned transaction: %v", err)
	}

	renewal := signer.sign(t, map[string]any{
		"transactionId": prefix + "-renewal", "originalTransactionId": originalID, "productId": productID,
		"bundleId": "com.xiguang.xiguang", "environment": "Sandbox", "appAccountToken": accountToken,
		"purchaseDate": now.Add(7 * 24 * time.Hour).UnixMilli(), "expiresDate": now.AddDate(0, 1, 7).UnixMilli(),
	})
	if _, err = paymentService.VerifyApple(t.Context(), userID, renewal); err != nil {
		t.Fatalf("Apple renewal failed: %v", err)
	}
	entitlement, err = repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Status != "active" {
		t.Fatalf("Apple renewal entitlement = %+v, %v", entitlement, err)
	}

	renewalInfo := signer.sign(t, map[string]any{
		"originalTransactionId": originalID, "autoRenewStatus": 0,
		"bundleId": "com.xiguang.xiguang", "environment": "Sandbox",
	})
	notification := signer.sign(t, map[string]any{
		"notificationUUID": prefix + "-cancel-event", "notificationType": "DID_CHANGE_RENEWAL_STATUS",
		"signedDate": now.Add(-2 * time.Second).UnixMilli(),
		"data":       map[string]any{"signedTransactionInfo": renewal, "signedRenewalInfo": renewalInfo},
	})
	processed, err := paymentService.ProcessAppleNotification(t.Context(), notification)
	if err != nil || !processed {
		t.Fatalf("Apple cancel notification = %v, %v", processed, err)
	}
	if metrics := paymentService.MetricsText(t.Context()); !strings.Contains(metrics, `xiguang_payment_webhook_delay_seconds_count{provider="apple"} 1`) {
		t.Fatalf("Apple webhook delay metric missing:\n%s", metrics)
	}
	entitlement, err = repo.Entitlement(t.Context(), userID)
	if err != nil || !entitlement.CancelAtPeriodEnd {
		t.Fatalf("Apple cancellation was not retained: %+v, %v", entitlement, err)
	}

	fakeDirect := &smokeDirectProvider{name: "alipay"}
	paymentService.providers["alipay"] = fakeDirect
	var directWasEnabled bool
	if err = pool.QueryRow(t.Context(), `SELECT enabled FROM billing_provider_products WHERE provider='alipay' AND external_product_id='com.xiguang.membership.starlight.month'`).Scan(&directWasEnabled); err != nil {
		t.Fatal(err)
	}
	_, _ = pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true WHERE provider='alipay' AND external_product_id='com.xiguang.membership.starlight.month'`)
	t.Cleanup(func() {
		_, _ = pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=$1 WHERE provider='alipay' AND external_product_id='com.xiguang.membership.starlight.month'`, directWasEnabled)
	})
	_, err = paymentService.CreateSubscription(t.Context(), userID, domain.CreateSubscriptionRequest{
		Provider: "alipay", ProductCode: "starlight_month", ClientRequestID: prefix + "-cross-channel",
	})
	if !errors.Is(err, repository.ErrActiveSubscription) {
		t.Fatalf("cross-channel duplicate purchase error = %v", err)
	}

	refunded := signer.sign(t, map[string]any{
		"transactionId": prefix + "-refund", "originalTransactionId": originalID, "productId": productID,
		"bundleId": "com.xiguang.xiguang", "environment": "Sandbox", "appAccountToken": accountToken,
		"purchaseDate": now.Add(8 * 24 * time.Hour).UnixMilli(), "expiresDate": now.AddDate(0, 1, 7).UnixMilli(),
		"revocationDate": now.Add(9 * 24 * time.Hour).UnixMilli(),
	})
	if _, err = paymentService.VerifyApple(t.Context(), userID, refunded); err != nil {
		t.Fatalf("Apple refund failed: %v", err)
	}
	entitlement, err = repo.Entitlement(t.Context(), userID)
	if err != nil || entitlement.Tier != "glimmer" || entitlement.Status != "revoked" {
		t.Fatalf("Apple refund entitlement = %+v, %v", entitlement, err)
	}
}

type smokeDirectProvider struct {
	name      string
	startErrs []error
	charges   []smokeCharge
	cancelled bool
}

type smokeCharge struct {
	transactionID string
	paidAt        time.Time
	err           error
}

func TestDirectCheckoutFailureClosesOrderForImmediateRetry(t *testing.T) {
	repo, pool, userID := serviceIntegrationRepo(t)
	const providerName = "alipay"
	const externalProductID = "com.xiguang.membership.starlight.month"
	var wasEnabled bool
	if err := pool.QueryRow(t.Context(), `SELECT enabled FROM billing_provider_products
		WHERE provider=$1 AND external_product_id=$2`, providerName, externalProductID).Scan(&wasEnabled); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now()
		WHERE provider=$1 AND external_product_id=$2`, providerName, externalProductID); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `UPDATE billing_provider_products SET enabled=$3
			WHERE provider=$1 AND external_product_id=$2`, providerName, externalProductID, wasEnabled)
	})

	provider := &smokeDirectProvider{
		name:      providerName,
		startErrs: []error{errors.New("simulated agreement outage")},
	}
	paymentService := New(repo, config.Config{
		PaymentEnabled: true, PaymentEnvironment: "sandbox", PaymentChannels: []string{providerName},
		PaymentEncryptionKey: "01234567890123456789012345678901",
	}, provider)
	paymentService.initialized.Store(true)
	if _, err := paymentService.CreateSubscription(t.Context(), userID, domain.CreateSubscriptionRequest{
		Provider: providerName, ProductCode: "starlight_month", ClientRequestID: "failed-checkout",
	}); err == nil {
		t.Fatal("agreement start failure was accepted")
	}
	var status, failureCode string
	if err := pool.QueryRow(t.Context(), `SELECT status::text,COALESCE(failure_code,'') FROM payment_orders
		WHERE user_id=$1 AND client_request_id='failed-checkout'`, userID).Scan(&status, &failureCode); err != nil {
		t.Fatal(err)
	}
	if status != "failed" || failureCode != "agreement_start_failed" {
		t.Fatalf("failed checkout state = %s/%s", status, failureCode)
	}
	result, err := paymentService.CreateSubscription(t.Context(), userID, domain.CreateSubscriptionRequest{
		Provider: providerName, ProductCode: "starlight_month", ClientRequestID: "retry-checkout",
	})
	if err != nil || result.Order.Status != "pending" {
		t.Fatalf("immediate retry = %+v, %v", result, err)
	}
}

func TestDirectDebitSimulatedTrialRenewalRetriesRecoveryCancelAndExpiry(t *testing.T) {
	for _, providerName := range []string{"wechat", "alipay"} {
		t.Run(providerName, func(t *testing.T) {
			repo, pool, userID := serviceIntegrationRepo(t)
			const externalProductID = "com.xiguang.membership.starlight.year"
			var wasEnabled bool
			if err := pool.QueryRow(t.Context(), `SELECT enabled FROM billing_provider_products WHERE provider::text=$1 AND external_product_id=$2`,
				providerName, externalProductID).Scan(&wasEnabled); err != nil {
				t.Fatal(err)
			}
			if _, err := pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now()
				WHERE provider::text=$1 AND external_product_id=$2`, providerName, externalProductID); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				_, _ = pool.Exec(context.Background(), `UPDATE billing_provider_products SET enabled=$3
					WHERE provider::text=$1 AND external_product_id=$2`, providerName, externalProductID, wasEnabled)
			})
			provider := &smokeDirectProvider{name: providerName}
			paymentService := New(repo, config.Config{
				PaymentEnabled: true, PaymentEnvironment: "sandbox", PaymentChannels: []string{providerName},
				PaymentEncryptionKey: "01234567890123456789012345678901",
			}, provider)
			paymentService.initialized.Store(true)
			prefix := fmt.Sprintf("%s-lifecycle-%d", providerName, time.Now().UnixNano())
			result, err := paymentService.CreateSubscription(t.Context(), userID, domain.CreateSubscriptionRequest{
				Provider: providerName, ProductCode: "starlight_year", ClientRequestID: prefix + "-checkout",
			})
			if err != nil || result.Order.Status != "pending" {
				t.Fatalf("checkout = %+v, %v", result, err)
			}
			now := time.Now().UTC().Truncate(time.Second)
			agreementID := prefix + "-agreement"
			if err = repo.ActivateAgreement(t.Context(), providerName, result.Order.PublicID, agreementID,
				fmt.Sprintf("%064x", userID), now); err != nil {
				t.Fatal(err)
			}
			entitlement, err := repo.Entitlement(t.Context(), userID)
			if err != nil || entitlement.Status != "trialing" || entitlement.Tier != "starlight" {
				t.Fatalf("trial entitlement = %+v, %v", entitlement, err)
			}
			if _, err = pool.Exec(t.Context(), `UPDATE subscriptions SET current_period_end=now()-interval '1 second',next_retry_at=now()-interval '1 second'
				WHERE user_id=$1`, userID); err != nil {
				t.Fatal(err)
			}
			provider.charges = append(provider.charges, smokeCharge{transactionID: prefix + "-first-charge", paidAt: now})
			if err = paymentService.RunDirectRenewals(t.Context()); err != nil {
				t.Fatal(err)
			}
			entitlement, err = repo.Entitlement(t.Context(), userID)
			if err != nil || entitlement.Status != "active" {
				t.Fatalf("first charge entitlement = %+v, %v", entitlement, err)
			}

			if _, err = pool.Exec(t.Context(), `UPDATE subscriptions SET current_period_end=now()-interval '1 second',next_retry_at=now()-interval '1 second'
				WHERE user_id=$1`, userID); err != nil {
				t.Fatal(err)
			}
			for attempt := 1; attempt <= 3; attempt++ {
				provider.charges = append(provider.charges, smokeCharge{err: fmt.Errorf("simulated failure %d", attempt)})
				if err = paymentService.RunDirectRenewals(t.Context()); err != nil {
					t.Fatal(err)
				}
				if attempt < 3 {
					if _, err = pool.Exec(t.Context(), `UPDATE subscriptions SET next_retry_at=now()-interval '1 second' WHERE user_id=$1`, userID); err != nil {
						t.Fatal(err)
					}
				}
			}
			entitlement, err = repo.Entitlement(t.Context(), userID)
			if err != nil || entitlement.Status != "grace" || entitlement.GraceUntil == nil || entitlement.Tier != "starlight" {
				t.Fatalf("grace entitlement = %+v, %v", entitlement, err)
			}
			if _, err = pool.Exec(t.Context(), `UPDATE subscriptions SET next_retry_at=now()-interval '1 second' WHERE user_id=$1`, userID); err != nil {
				t.Fatal(err)
			}
			provider.charges = append(provider.charges, smokeCharge{transactionID: prefix + "-recovered-charge", paidAt: now.Add(time.Hour)})
			if err = paymentService.RunDirectRenewals(t.Context()); err != nil {
				t.Fatal(err)
			}
			entitlement, err = repo.Entitlement(t.Context(), userID)
			if err != nil || entitlement.Status != "active" || entitlement.GraceUntil != nil {
				t.Fatalf("recovered entitlement = %+v, %v", entitlement, err)
			}

			var subscriptionID string
			if err = pool.QueryRow(t.Context(), `SELECT public_id::text FROM subscriptions WHERE user_id=$1`, userID).Scan(&subscriptionID); err != nil {
				t.Fatal(err)
			}
			cancelled, err := paymentService.Cancel(t.Context(), userID, subscriptionID)
			if err != nil || !cancelled || !provider.cancelled {
				t.Fatalf("cancel = %v provider=%v err=%v", cancelled, provider.cancelled, err)
			}
			if _, err = pool.Exec(t.Context(), `UPDATE subscriptions SET current_period_end=now()-interval '1 second' WHERE user_id=$1`, userID); err != nil {
				t.Fatal(err)
			}
			if err = repo.Sweep(t.Context()); err != nil {
				t.Fatal(err)
			}
			entitlement, err = repo.Entitlement(t.Context(), userID)
			if err != nil || entitlement.Tier != "glimmer" || entitlement.Status != "expired" {
				t.Fatalf("expired entitlement = %+v, %v", entitlement, err)
			}
		})
	}
}

func (p *smokeDirectProvider) Name() string { return p.name }
func (p *smokeDirectProvider) VerifyProducts(_ context.Context, products []domain.Product) ([]string, error) {
	ids := make([]string, 0, len(products))
	for _, product := range products {
		ids = append(ids, product.ExternalProductID)
	}
	return ids, nil
}
func (p *smokeDirectProvider) StartAgreement(_ context.Context, _ domain.Order, _ domain.Product) (map[string]any, error) {
	if len(p.startErrs) > 0 {
		err := p.startErrs[0]
		p.startErrs = p.startErrs[1:]
		return nil, err
	}
	return map[string]any{"simulated": true}, nil
}
func (p *smokeDirectProvider) Charge(_ context.Context, _ domain.RenewalCandidate) (string, time.Time, error) {
	if len(p.charges) == 0 {
		return "", time.Time{}, errors.New("no simulated charge")
	}
	result := p.charges[0]
	p.charges = p.charges[1:]
	return result.transactionID, result.paidAt, result.err
}
func (p *smokeDirectProvider) QueryCharge(_ context.Context, _ domain.RenewalCandidate) (string, time.Time, bool, error) {
	return "", time.Time{}, false, nil
}
func (p *smokeDirectProvider) Cancel(_ context.Context, _ string) error {
	p.cancelled = true
	return nil
}
