package repository_test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/billing/repository"
	infraDB "xiguang/backend/internal/infra/db"
)

func integrationRepo(t *testing.T) (*repository.PG, *pgxpool.Pool, int64) {
	t.Helper()
	dsn := os.Getenv("BILLING_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("BILLING_TEST_DATABASE_URL is not configured")
	}
	ctx := context.Background()
	pool, err := infraDB.Connect(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	username := fmt.Sprintf("billing_it_%d", time.Now().UnixNano())
	var userID int64
	err = pool.QueryRow(ctx, `INSERT INTO users(username,password_hash,nickname) VALUES($1,'test','billing') RETURNING id`, username).Scan(&userID)
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

func TestConcurrentCheckoutAllowsOnlyOneOpenOrder(t *testing.T) {
	repo, _, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	product.ProviderEnabled = true

	var successes atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if _, createErr := repo.CreatePendingOrder(ctx, userID, product, "alipay", fmt.Sprintf("request-%d", i)); createErr == nil {
				successes.Add(1)
			}
		}(i)
	}
	wg.Wait()
	if got := successes.Load(); got != 1 {
		t.Fatalf("successful open orders = %d, want 1", got)
	}
}

func TestRenewalLeaseIsClaimedOnce(t *testing.T) {
	repo, pool, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	product.ProviderEnabled = true
	order, err := repo.CreatePendingOrder(ctx, userID, product, "alipay", "first-payment")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	_, err = repo.ApplyProviderPayment(ctx, domain.ProviderPayment{
		Provider: "alipay", OrderID: order.PublicID, TransactionID: "trade-first",
		ExternalSubscriptionID: "agreement-once", PaidAt: now,
		PeriodStart: now.AddDate(0, -1, 0), PeriodEnd: now.Add(-time.Minute),
	})
	if err != nil {
		t.Fatal(err)
	}
	_, err = pool.Exec(ctx, `UPDATE subscriptions SET next_retry_at=now()-interval '1 minute' WHERE user_id=$1`, userID)
	if err != nil {
		t.Fatal(err)
	}

	start := make(chan struct{})
	counts := make(chan int, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			items, claimErr := repo.ClaimDueRenewals(ctx, "alipay", 10)
			if claimErr != nil {
				counts <- -100
				return
			}
			counts <- len(items)
		}()
	}
	close(start)
	wg.Wait()
	close(counts)
	total := 0
	for count := range counts {
		total += count
	}
	if total != 1 {
		t.Fatalf("total claimed renewals = %d, want 1", total)
	}
}

func TestConcurrentStorageReservationCannotExceedQuota(t *testing.T) {
	repo, _, userID := integrationRepo(t)
	ctx := context.Background()
	var successes atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if err := repo.ReserveStorage(ctx, userID, fmt.Sprintf("billing-it/%d", i), 700<<20); err == nil {
				successes.Add(1)
			}
		}(i)
	}
	wg.Wait()
	if got := successes.Load(); got != 1 {
		t.Fatalf("successful storage reservations = %d, want 1", got)
	}
}

func TestFirstStorageReservationCountsExistingMediaWithoutEntitlementRow(t *testing.T) {
	repo, pool, userID := integrationRepo(t)
	ctx := context.Background()
	var fragmentID int64
	if err := pool.QueryRow(ctx, `INSERT INTO fragments(user_id,content_text,status) VALUES($1,'existing media','twilight') RETURNING id`, userID).Scan(&fragmentID); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO media_files(user_id,fragment_id,media_type,object_key,file_name,file_size,mime_type)
		VALUES($1,$2,'image',$3,'existing.jpg',$4,'image/jpeg')`, userID, fragmentID, fmt.Sprintf("users/%d/media/existing.jpg", userID), 900<<20); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `DELETE FROM user_entitlements WHERE user_id=$1`, userID); err != nil {
		t.Fatal(err)
	}

	err := repo.ReserveStorage(ctx, userID, fmt.Sprintf("users/%d/media/new.jpg", userID), 200<<20)
	if !errors.Is(err, repository.ErrStorageQuota) {
		t.Fatalf("ReserveStorage() error = %v, want quota exceeded", err)
	}
}

func TestConcurrentAIReservationHonorsQuotaAndRelease(t *testing.T) {
	repo, pool, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "galaxy_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	product.ProviderEnabled = true
	order, err := repo.CreatePendingOrder(ctx, userID, product, "alipay", "ai-payment")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	_, err = repo.ApplyProviderPayment(ctx, domain.ProviderPayment{
		Provider: "alipay", OrderID: order.PublicID, TransactionID: "trade-ai",
		ExternalSubscriptionID: "agreement-ai", PaidAt: now, PeriodStart: now, PeriodEnd: now.AddDate(0, 1, 0),
	})
	if err != nil {
		t.Fatal(err)
	}
	_, err = pool.Exec(ctx, `UPDATE user_entitlements SET ai_quota=3 WHERE user_id=$1`, userID)
	if err != nil {
		t.Fatal(err)
	}

	var successes atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if reserveErr := repo.ReserveAI(ctx, userID); reserveErr == nil {
				successes.Add(1)
			}
		}()
	}
	wg.Wait()
	if got := successes.Load(); got != 3 {
		t.Fatalf("successful AI reservations = %d, want 3", got)
	}
	repo.ReleaseAI(ctx, userID)
	if err = repo.ReserveAI(ctx, userID); err != nil {
		t.Fatalf("quota was not returned after failed AI request: %v", err)
	}
}

func TestWebhookReplayAndFailedEventReclaim(t *testing.T) {
	repo, pool, _ := integrationRepo(t)
	ctx := context.Background()
	payload := []byte("encrypted-test-payload")
	eventID := fmt.Sprintf("replay-%d", time.Now().UnixNano())
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM payment_events WHERE external_event_id=$1`, eventID)
	})
	claimed, err := repo.RecordEvent(ctx, "alipay", eventID, "agreement", payload, fmt.Sprintf("%064d", 2))
	if err != nil || !claimed {
		t.Fatalf("first replay event claim = %v, %v", claimed, err)
	}
	claimed, err = repo.RecordEvent(ctx, "alipay", eventID, "agreement", payload, fmt.Sprintf("%064d", 2))
	if err != nil || claimed {
		t.Fatalf("processed in-flight replay claim = %v, %v", claimed, err)
	}
	if err = repo.MarkEvent(ctx, "alipay", eventID, "failed", "temporary"); err != nil {
		t.Fatal(err)
	}
	claimed, err = repo.RecordEvent(ctx, "alipay", eventID, "agreement", payload, fmt.Sprintf("%064d", 2))
	if err != nil || !claimed {
		t.Fatalf("failed event reclaim = %v, %v", claimed, err)
	}
}

func TestAnnualAgreementTrialThenFirstCharge(t *testing.T) {
	repo, pool, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_year", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	product.ProviderEnabled = true
	order, err := repo.CreatePendingOrder(ctx, userID, product, "alipay", "annual-trial")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	if err = repo.ActivateAgreement(ctx, "alipay", order.PublicID, "agreement-trial", fmt.Sprintf("%064d", 9), now); err != nil {
		t.Fatal(err)
	}
	entitlement, err := repo.Entitlement(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if entitlement.Tier != "starlight" || entitlement.Status != "trialing" || entitlement.ValidUntil == nil {
		t.Fatalf("unexpected trial entitlement: %+v", entitlement)
	}
	items, err := repo.ClaimDueRenewals(ctx, "alipay", 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 0 {
		t.Fatalf("trial was charged early: %d candidates", len(items))
	}
	_, err = pool.Exec(ctx, `UPDATE subscriptions SET current_period_end=now()-interval '1 minute',next_retry_at=now()-interval '1 minute' WHERE user_id=$1`, userID)
	if err != nil {
		t.Fatal(err)
	}
	items, err = repo.ClaimDueRenewals(ctx, "alipay", 10)
	if err != nil || len(items) != 1 {
		t.Fatalf("first charge candidates = %d, %v", len(items), err)
	}
	if err = repo.CompleteRenewal(ctx, items[0], "trial-first-trade", now); err != nil {
		t.Fatal(err)
	}
	paidOrder, err := repo.Order(ctx, userID, order.PublicID)
	if err != nil || paidOrder.Status != "paid" || paidOrder.TransactionID != "trial-first-trade" {
		t.Fatalf("initial order not paid after first charge: %+v, %v", paidOrder, err)
	}
	var periodEndBefore, periodEndAfter time.Time
	if err = pool.QueryRow(ctx, `SELECT current_period_end FROM subscriptions WHERE user_id=$1`, userID).Scan(&periodEndBefore); err != nil {
		t.Fatal(err)
	}
	if err = repo.CompleteRenewal(ctx, items[0], "trial-first-trade", now); err != nil {
		t.Fatal(err)
	}
	if err = pool.QueryRow(ctx, `SELECT current_period_end FROM subscriptions WHERE user_id=$1`, userID).Scan(&periodEndAfter); err != nil {
		t.Fatal(err)
	}
	if !periodEndAfter.Equal(periodEndBefore) {
		t.Fatalf("duplicate renewal advanced the subscription twice: %s -> %s", periodEndBefore, periodEndAfter)
	}
}

func TestAnnualTrialCannotBeRedeemedBySamePayerAcrossAccounts(t *testing.T) {
	repo, pool, firstUserID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_year", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	product.ProviderEnabled = true
	payerHash := fmt.Sprintf("%064d", 77)
	firstOrder, err := repo.CreatePendingOrder(ctx, firstUserID, product, "alipay", "trial-first-account")
	if err != nil {
		t.Fatal(err)
	}
	if err = repo.ActivateAgreement(ctx, "alipay", firstOrder.PublicID, "trial-first-agreement", payerHash, time.Now().UTC()); err != nil {
		t.Fatal(err)
	}

	var secondUserID int64
	err = pool.QueryRow(ctx, `INSERT INTO users(username,password_hash,nickname) VALUES($1,'test','billing') RETURNING id`,
		fmt.Sprintf("billing_it_second_%d", time.Now().UnixNano())).Scan(&secondUserID)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, secondUserID) })
	secondOrder, err := repo.CreatePendingOrder(ctx, secondUserID, product, "alipay", "trial-second-account")
	if err != nil {
		t.Fatal(err)
	}
	if err = repo.ActivateAgreement(ctx, "alipay", secondOrder.PublicID, "trial-second-agreement", payerHash, time.Now().UTC()); err != nil {
		t.Fatal(err)
	}
	secondEntitlement, err := repo.Entitlement(ctx, secondUserID)
	if err != nil {
		t.Fatal(err)
	}
	if secondEntitlement.Tier != "glimmer" {
		t.Fatalf("same payer received a second trial: %+v", secondEntitlement)
	}
	var status string
	if err = pool.QueryRow(ctx, `SELECT status::text FROM subscriptions WHERE user_id=$1`, secondUserID).Scan(&status); err != nil {
		t.Fatal(err)
	}
	if status != "past_due" {
		t.Fatalf("second agreement status = %s, want immediate first charge", status)
	}
}

func TestAppleIntroductoryOfferCreatesTrialingEntitlement(t *testing.T) {
	repo, _, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_year", "apple")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	_, err = repo.ApplyAppleTransaction(ctx, userID, product, domain.AppleTransaction{
		TransactionID:         fmt.Sprintf("apple-trial-%d", time.Now().UnixNano()),
		OriginalTransactionID: fmt.Sprintf("apple-original-%d", time.Now().UnixNano()),
		OfferType:             1,
		PurchaseAt:            now,
		ExpiresAt:             now.Add(7 * 24 * time.Hour),
	})
	if err != nil {
		t.Fatal(err)
	}
	entitlement, err := repo.Entitlement(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if entitlement.Status != "trialing" || entitlement.Tier != "starlight" {
		t.Fatalf("unexpected Apple introductory entitlement: %+v", entitlement)
	}
}

func TestApplePurchaseRejectsExistingDirectSubscription(t *testing.T) {
	repo, _, userID := integrationRepo(t)
	ctx := context.Background()
	directProduct, err := repo.ProductByCode(ctx, "starlight_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	order, err := repo.CreatePendingOrder(ctx, userID, directProduct, "alipay", "cross-channel-direct")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	_, err = repo.ApplyProviderPayment(ctx, domain.ProviderPayment{
		Provider: "alipay", OrderID: order.PublicID, TransactionID: "cross-channel-trade",
		ExternalSubscriptionID: "cross-channel-agreement", PaidAt: now,
		PeriodStart: now, PeriodEnd: now.AddDate(0, 1, 0),
	})
	if err != nil {
		t.Fatal(err)
	}
	appleProduct, err := repo.ProductByCode(ctx, "galaxy_month", "apple")
	if err != nil {
		t.Fatal(err)
	}
	_, err = repo.ApplyAppleTransaction(ctx, userID, appleProduct, domain.AppleTransaction{
		TransactionID:         "cross-channel-apple-trade",
		OriginalTransactionID: "cross-channel-apple-original",
		PurchaseAt:            now,
		ExpiresAt:             now.AddDate(0, 1, 0),
	})
	if !errors.Is(err, repository.ErrActiveSubscription) {
		t.Fatalf("Apple cross-channel purchase error = %v, want %v", err, repository.ErrActiveSubscription)
	}
}

func TestRefundKeepsRevokedStatusVisibleAfterDowngrade(t *testing.T) {
	repo, _, userID := integrationRepo(t)
	ctx := context.Background()
	product, err := repo.ProductByCode(ctx, "starlight_month", "alipay")
	if err != nil {
		t.Fatal(err)
	}
	order, err := repo.CreatePendingOrder(ctx, userID, product, "alipay", "refund-visible")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	_, err = repo.ApplyProviderPayment(ctx, domain.ProviderPayment{
		Provider: "alipay", OrderID: order.PublicID, TransactionID: "refund-visible-trade",
		ExternalSubscriptionID: "refund-visible-agreement", PaidAt: now,
		PeriodStart: now, PeriodEnd: now.AddDate(0, 1, 0),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err = repo.RevokeProviderTransaction(ctx, "alipay", "refund-visible-trade", now.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	entitlement, err := repo.Entitlement(ctx, userID)
	if err != nil {
		t.Fatal(err)
	}
	if entitlement.Tier != "glimmer" || entitlement.Status != "revoked" || entitlement.Provider != "alipay" {
		t.Fatalf("refund state was lost after downgrade: %+v", entitlement)
	}
}
