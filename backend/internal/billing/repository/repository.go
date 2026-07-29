package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"xiguang/backend/internal/billing/domain"
)

var (
	ErrNotFound            = errors.New("billing_not_found")
	ErrActiveSubscription  = errors.New("active_subscription_exists")
	ErrProductUnavailable  = errors.New("product_unavailable")
	ErrStorageQuota        = errors.New("storage_quota_exceeded")
	ErrAIQuota             = errors.New("ai_quota_exceeded")
	ErrEntitlementRequired = errors.New("entitlement_required")
	ErrTransactionOwner    = errors.New("transaction_belongs_to_another_user")
)

type PG struct{ db *pgxpool.Pool }

func NewPG(db *pgxpool.Pool) *PG { return &PG{db: db} }

func (r *PG) Catalog(ctx context.Context, provider string) ([]domain.Product, error) {
	rows, err := r.db.Query(ctx, `SELECT p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,
		p.storage_quota_bytes,p.ai_quota,COALESCE(pp.external_product_id,''),COALESCE(pp.enabled,false)
		FROM billing_products p LEFT JOIN billing_provider_products pp
		ON pp.product_id=p.id AND pp.provider::text=$1 WHERE p.active=true ORDER BY p.price_cents`, provider)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []domain.Product{}
	for rows.Next() {
		var p domain.Product
		if err := rows.Scan(&p.ID, &p.Code, &p.Tier, &p.Period, &p.PriceCents, &p.Currency, &p.TrialDays,
			&p.StorageQuotaBytes, &p.AIQuota, &p.ExternalProductID, &p.ProviderEnabled); err != nil {
			return nil, err
		}
		p.Provider = provider
		items = append(items, p)
	}
	return items, rows.Err()
}

func (r *PG) ProductByCode(ctx context.Context, code, provider string) (domain.Product, error) {
	var p domain.Product
	err := r.db.QueryRow(ctx, `SELECT p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,
		p.storage_quota_bytes,p.ai_quota,COALESCE(pp.external_product_id,''),COALESCE(pp.enabled,false)
		FROM billing_products p LEFT JOIN billing_provider_products pp ON pp.product_id=p.id AND pp.provider::text=$2
		WHERE p.code=$1 AND p.active=true`, code, provider).Scan(&p.ID, &p.Code, &p.Tier, &p.Period, &p.PriceCents,
		&p.Currency, &p.TrialDays, &p.StorageQuotaBytes, &p.AIQuota, &p.ExternalProductID, &p.ProviderEnabled)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, ErrNotFound
	}
	p.Provider = provider
	return p, err
}

func (r *PG) ProductByExternalID(ctx context.Context, provider, externalID string) (domain.Product, error) {
	var p domain.Product
	err := r.db.QueryRow(ctx, `SELECT p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,
		p.storage_quota_bytes,p.ai_quota,pp.external_product_id,pp.enabled FROM billing_products p
		JOIN billing_provider_products pp ON pp.product_id=p.id
		WHERE pp.provider::text=$1 AND pp.external_product_id=$2 AND p.active=true`, provider, externalID).
		Scan(&p.ID, &p.Code, &p.Tier, &p.Period, &p.PriceCents, &p.Currency, &p.TrialDays, &p.StorageQuotaBytes,
			&p.AIQuota, &p.ExternalProductID, &p.ProviderEnabled)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, ErrNotFound
	}
	p.Provider = provider
	return p, err
}

func (r *PG) UserIDByPublicID(ctx context.Context, publicID string) (int64, error) {
	var id int64
	err := r.db.QueryRow(ctx, `SELECT id FROM users WHERE public_id::text=$1 AND deleted_at IS NULL`, publicID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return id, err
}

func (r *PG) UserIDByAppleSubscription(ctx context.Context, originalID string) (int64, error) {
	var id int64
	err := r.db.QueryRow(ctx, `SELECT user_id FROM subscriptions WHERE provider='apple' AND external_subscription_id=$1`, originalID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNotFound
	}
	return id, err
}

func (r *PG) ActiveAppleSubscriptions(ctx context.Context) ([]domain.AppleSubscriptionRef, error) {
	rows, err := r.db.Query(ctx, `SELECT user_id,external_subscription_id FROM subscriptions
		WHERE provider='apple' AND status IN ('trialing','active','grace','past_due')
		AND external_subscription_id IS NOT NULL`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []domain.AppleSubscriptionRef{}
	for rows.Next() {
		var item domain.AppleSubscriptionRef
		if err := rows.Scan(&item.UserID, &item.OriginalTransactionID); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *PG) Entitlement(ctx context.Context, userID int64) (domain.Entitlement, error) {
	_, err := r.db.Exec(ctx, `INSERT INTO user_entitlements(user_id) VALUES($1) ON CONFLICT(user_id) DO NOTHING`, userID)
	if err != nil {
		return domain.Entitlement{}, err
	}
	var e domain.Entitlement
	err = r.db.QueryRow(ctx, `SELECT ue.tier::text,COALESCE(s.status::text,'active'),COALESCE(s.provider::text,''),
		COALESCE(p.code,''),COALESCE(s.public_id::text,''),ue.valid_until,ue.grace_until,COALESCE(s.cancel_at_period_end,false),
		ue.storage_quota_bytes,COALESCE((SELECT SUM(file_size) FROM media_files WHERE user_id=$1 AND deleted_at IS NULL),0),
		ue.ai_quota,COALESCE((SELECT used FROM usage_counters WHERE user_id=$1 AND metric='ai'
			AND now()>=period_start AND now()<period_end ORDER BY period_start DESC LIMIT 1),0),ue.version
		FROM user_entitlements ue LEFT JOIN LATERAL (
			SELECT candidate.* FROM subscriptions candidate WHERE candidate.user_id=ue.user_id
			ORDER BY (candidate.id=ue.source_subscription_id) DESC,candidate.updated_at DESC,candidate.id DESC LIMIT 1
		) s ON true
		LEFT JOIN billing_products p ON p.id=s.product_id WHERE ue.user_id=$1`, userID).
		Scan(&e.Tier, &e.Status, &e.Provider, &e.ProductCode, &e.SubscriptionID, &e.ValidUntil, &e.GraceUntil, &e.CancelAtPeriodEnd,
			&e.StorageQuotaBytes, &e.StorageUsedBytes, &e.AIQuota, &e.AIUsed, &e.EntitlementVersion)
	return e, err
}

func (r *PG) EntitlementMismatchCount(ctx context.Context) (int64, error) {
	var count int64
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM subscriptions s
		JOIN billing_products p ON p.id=s.product_id
		LEFT JOIN user_entitlements ue ON ue.user_id=s.user_id
		WHERE s.status IN ('trialing','active','grace','past_due')
		AND (ue.user_id IS NULL OR ue.source_subscription_id IS DISTINCT FROM s.id OR ue.tier::text<>p.tier::text)`).Scan(&count)
	return count, err
}

func (r *PG) CreatePendingOrder(ctx context.Context, userID int64, p domain.Product, provider, requestID string) (domain.Order, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Order{}, err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, userID); err != nil {
		return domain.Order{}, err
	}
	var exists bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM subscriptions WHERE user_id=$1 AND status IN ('trialing','active','grace','past_due'))`, userID).Scan(&exists)
	if err != nil {
		return domain.Order{}, err
	}
	if exists {
		return domain.Order{}, ErrActiveSubscription
	}
	if _, err = tx.Exec(ctx, `UPDATE payment_orders SET status='closed',failure_code='expired_checkout',updated_at=now()
		WHERE user_id=$1 AND status IN ('created','pending') AND created_at<now()-interval '30 minutes'`, userID); err != nil {
		return domain.Order{}, err
	}
	var o domain.Order
	err = tx.QueryRow(ctx, `INSERT INTO payment_orders(user_id,product_id,provider,client_request_id,amount_cents,currency,status)
		VALUES($1,$2,$3,$4,$5,$6,'pending') ON CONFLICT(user_id,client_request_id) DO UPDATE SET updated_at=now()
		RETURNING public_id::text,$7,provider::text,amount_cents,currency,status::text,COALESCE(failure_code,''),COALESCE(transaction_id,''),paid_at,created_at`,
		userID, p.ID, provider, requestID, p.PriceCents, p.Currency, p.Code).
		Scan(&o.PublicID, &o.ProductCode, &o.Provider, &o.AmountCents, &o.Currency, &o.Status, &o.FailureCode, &o.TransactionID, &o.PaidAt, &o.CreatedAt)
	if err != nil {
		return o, err
	}
	return o, tx.Commit(ctx)
}

func (r *PG) Order(ctx context.Context, userID int64, publicID string) (domain.Order, error) {
	var o domain.Order
	err := r.db.QueryRow(ctx, `SELECT po.public_id::text,p.code,po.provider::text,po.amount_cents,po.currency,po.status::text,
		COALESCE(po.failure_code,''),COALESCE(po.transaction_id,''),po.paid_at,po.created_at
		FROM payment_orders po JOIN billing_products p ON p.id=po.product_id WHERE po.user_id=$1 AND po.public_id=$2`, userID, publicID).
		Scan(&o.PublicID, &o.ProductCode, &o.Provider, &o.AmountCents, &o.Currency, &o.Status, &o.FailureCode, &o.TransactionID, &o.PaidAt, &o.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return o, ErrNotFound
	}
	return o, err
}

func (r *PG) FailOrder(ctx context.Context, userID int64, publicID, code string) error {
	if code == "" {
		code = "payment_start_failed"
	}
	result, err := r.db.Exec(ctx, `UPDATE payment_orders
		SET status='failed',failure_code=$3,updated_at=now()
		WHERE user_id=$1 AND public_id=$2 AND status IN ('created','pending')`,
		userID, publicID, code)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ApplyProviderPayment atomically applies a verified non-Apple first payment.
func (r *PG) ApplyProviderPayment(ctx context.Context, payment domain.ProviderPayment) (domain.Order, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Order{}, err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, payment.Provider+":"+payment.ExternalSubscriptionID); err != nil {
		return domain.Order{}, err
	}
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, payment.Provider+":"+payment.TransactionID); err != nil {
		return domain.Order{}, err
	}

	var o domain.Order
	var orderID, userID, productID int64
	var p domain.Product
	err = tx.QueryRow(ctx, `SELECT po.id,po.user_id,po.product_id,po.public_id::text,bp.code,bp.tier::text,bp.period::text,
		po.provider::text,po.amount_cents,po.currency,po.status::text,COALESCE(po.failure_code,''),COALESCE(po.transaction_id,''),
		po.paid_at,po.created_at,bp.storage_quota_bytes,bp.ai_quota,bp.trial_days
		FROM payment_orders po JOIN billing_products bp ON bp.id=po.product_id
		WHERE po.public_id=$1 AND po.provider::text=$2 FOR UPDATE`, payment.OrderID, payment.Provider).
		Scan(&orderID, &userID, &productID, &o.PublicID, &o.ProductCode, &p.Tier, &p.Period, &o.Provider,
			&o.AmountCents, &o.Currency, &o.Status, &o.FailureCode, &o.TransactionID, &o.PaidAt, &o.CreatedAt,
			&p.StorageQuotaBytes, &p.AIQuota, &p.TrialDays)
	if errors.Is(err, pgx.ErrNoRows) {
		return o, ErrNotFound
	}
	if err != nil {
		return o, err
	}
	p.ID, p.Code, p.PriceCents, p.Currency = productID, o.ProductCode, o.AmountCents, o.Currency
	if o.Status == "paid" && o.TransactionID == payment.TransactionID {
		return o, tx.Commit(ctx)
	}
	if o.Status != "pending" && o.Status != "created" {
		return o, ErrProductUnavailable
	}

	var existingUserID int64
	err = tx.QueryRow(ctx, `SELECT user_id FROM subscriptions WHERE provider::text=$1 AND external_subscription_id=$2 FOR UPDATE`,
		payment.Provider, payment.ExternalSubscriptionID).Scan(&existingUserID)
	if err == nil && existingUserID != userID {
		return o, ErrTransactionOwner
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return o, err
	}
	status := "active"
	if payment.PeriodStart.After(payment.PaidAt) {
		status = "trialing"
	}
	var subID int64
	err = tx.QueryRow(ctx, `INSERT INTO subscriptions(user_id,product_id,provider,external_subscription_id,status,current_period_start,current_period_end,next_retry_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$7)
		ON CONFLICT(provider,external_subscription_id) DO UPDATE SET product_id=excluded.product_id,status=excluded.status,
		current_period_start=excluded.current_period_start,current_period_end=excluded.current_period_end,retry_count=0,
		next_retry_at=excluded.current_period_end,grace_until=NULL,updated_at=now()
		RETURNING id`, userID, productID, payment.Provider, payment.ExternalSubscriptionID, status, payment.PeriodStart, payment.PeriodEnd).Scan(&subID)
	if err != nil {
		return o, err
	}
	_, err = tx.Exec(ctx, `UPDATE payment_orders SET status='paid',transaction_id=$2,external_order_id=$3,paid_at=$4,
		failure_code=NULL,updated_at=now() WHERE id=$1`, orderID, payment.TransactionID, payment.ExternalSubscriptionID, payment.PaidAt)
	if err != nil {
		return o, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id,tier,source_subscription_id,valid_until,storage_quota_bytes,ai_quota)
		VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id) DO UPDATE SET tier=excluded.tier,
		source_subscription_id=excluded.source_subscription_id,valid_until=excluded.valid_until,grace_until=NULL,
		storage_quota_bytes=excluded.storage_quota_bytes,ai_quota=excluded.ai_quota,version=user_entitlements.version+1,updated_at=now()`,
		userID, p.Tier, subID, payment.PeriodEnd, p.StorageQuotaBytes, p.AIQuota)
	if err != nil {
		return o, err
	}
	o.Status, o.TransactionID, o.PaidAt = "paid", payment.TransactionID, &payment.PaidAt
	var pendingRefundAt time.Time
	err = tx.QueryRow(ctx, `SELECT refunded_at FROM pending_payment_refunds WHERE provider::text=$1 AND transaction_id=$2`,
		payment.Provider, payment.TransactionID).Scan(&pendingRefundAt)
	if err == nil {
		if _, err = applyProviderRefundTx(ctx, tx, payment.Provider, payment.TransactionID, pendingRefundAt); err != nil {
			return o, err
		}
		o.Status = "refunded"
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return o, err
	}
	return o, tx.Commit(ctx)
}

// ActivateAgreement starts the free trial or schedules an immediate first
// charge after a provider confirms the recurring-payment agreement.
func (r *PG) ActivateAgreement(ctx context.Context, provider, orderPublicID, agreementID, payerSubjectHash string, signedAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, provider+":"+agreementID); err != nil {
		return err
	}
	var orderID, userID, productID int64
	var tier string
	var trialDays int
	var storageQuota int64
	var aiQuota int
	err = tx.QueryRow(ctx, `SELECT po.id,po.user_id,po.product_id,p.tier::text,p.trial_days,p.storage_quota_bytes,p.ai_quota
		FROM payment_orders po JOIN billing_products p ON p.id=po.product_id
		WHERE po.public_id=$1 AND po.provider::text=$2 AND po.status IN ('created','pending') FOR UPDATE`, orderPublicID, provider).
		Scan(&orderID, &userID, &productID, &tier, &trialDays, &storageQuota, &aiQuota)
	if errors.Is(err, pgx.ErrNoRows) {
		var existing bool
		err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM subscriptions WHERE provider::text=$1 AND external_subscription_id=$2)`, provider, agreementID).Scan(&existing)
		if err == nil && existing {
			return tx.Commit(ctx)
		}
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, userID); err != nil {
		return err
	}
	if trialDays > 0 {
		if payerSubjectHash == "" {
			trialDays = 0
		} else {
			var redeemed bool
			if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM trial_redemptions WHERE user_id=$1 AND product_family='membership')`, userID).Scan(&redeemed); err != nil {
				return err
			}
			if !redeemed {
				tag, insertErr := tx.Exec(ctx, `INSERT INTO trial_redemptions(provider,payer_subject_hash,product_family,user_id)
					VALUES($1,$2,'membership',$3) ON CONFLICT DO NOTHING`, provider, payerSubjectHash, userID)
				if insertErr != nil {
					return insertErr
				}
				redeemed = tag.RowsAffected() == 0
			}
			if redeemed {
				trialDays = 0
			}
		}
	}
	firstChargeAt := signedAt.AddDate(0, 0, trialDays)
	status := "past_due"
	if trialDays > 0 {
		status = "trialing"
	}
	var subID int64
	err = tx.QueryRow(ctx, `INSERT INTO subscriptions(user_id,product_id,provider,external_subscription_id,status,current_period_start,current_period_end,next_retry_at)
		VALUES($1,$2,$3,$4,$5,$6,$6,$6)
		ON CONFLICT(provider,external_subscription_id) DO UPDATE SET updated_at=now() RETURNING id`,
		userID, productID, provider, agreementID, status, firstChargeAt).Scan(&subID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE payment_orders SET external_order_id=$2,updated_at=now() WHERE id=$1`, orderID, agreementID)
	if err != nil {
		return err
	}
	if trialDays > 0 {
		_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id,tier,source_subscription_id,valid_until,storage_quota_bytes,ai_quota)
			VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id) DO UPDATE SET tier=excluded.tier,source_subscription_id=excluded.source_subscription_id,
			valid_until=excluded.valid_until,grace_until=NULL,storage_quota_bytes=excluded.storage_quota_bytes,ai_quota=excluded.ai_quota,
			version=user_entitlements.version+1,updated_at=now()`, userID, tier, subID, firstChargeAt, storageQuota, aiQuota)
		if err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func (r *PG) ApplyAppleTransaction(ctx context.Context, userID int64, p domain.Product, t domain.AppleTransaction) (domain.Order, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.Order{}, err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "apple:"+t.OriginalTransactionID); err != nil {
		return domain.Order{}, err
	}
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, userID); err != nil {
		return domain.Order{}, err
	}
	var activeProvider, activeExternalID string
	err = tx.QueryRow(ctx, `SELECT provider::text,COALESCE(external_subscription_id,'') FROM subscriptions
		WHERE user_id=$1 AND status IN ('trialing','active','grace','past_due')
		ORDER BY id LIMIT 1 FOR UPDATE`, userID).Scan(&activeProvider, &activeExternalID)
	if err == nil && (activeProvider != "apple" || activeExternalID != t.OriginalTransactionID) {
		return domain.Order{}, ErrActiveSubscription
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return domain.Order{}, err
	}
	status := "active"
	if t.OfferType == 1 && t.ExpiresAt.After(time.Now()) {
		status = "trialing"
	}
	if t.RevokedAt != nil {
		status = "revoked"
	}
	var subID int64
	applyEntitlement := true
	var currentUserID int64
	var currentStart, currentEnd time.Time
	err = tx.QueryRow(ctx, `SELECT id,user_id,current_period_start,current_period_end FROM subscriptions
		WHERE provider='apple' AND external_subscription_id=$1 FOR UPDATE`, t.OriginalTransactionID).
		Scan(&subID, &currentUserID, &currentStart, &currentEnd)
	if errors.Is(err, pgx.ErrNoRows) {
		err = tx.QueryRow(ctx, `INSERT INTO subscriptions(user_id,product_id,provider,external_subscription_id,status,current_period_start,current_period_end)
			VALUES($1,$2,'apple',$3,$4,$5,$6) RETURNING id`, userID, p.ID, t.OriginalTransactionID, status, t.PurchaseAt, t.ExpiresAt).
			Scan(&subID)
	} else if err == nil {
		if currentUserID != userID {
			return domain.Order{}, ErrTransactionOwner
		}
		applyEntitlement = shouldApplyAppleTransaction(currentStart, currentEnd, t)
		if applyEntitlement {
			_, err = tx.Exec(ctx, `UPDATE subscriptions SET product_id=$2,status=$3,current_period_start=$4,
				current_period_end=$5,updated_at=now() WHERE id=$1`, subID, p.ID, status, t.PurchaseAt, t.ExpiresAt)
		}
	}
	if err != nil {
		return domain.Order{}, err
	}
	var o domain.Order
	err = tx.QueryRow(ctx, `INSERT INTO payment_orders(user_id,product_id,provider,client_request_id,transaction_id,amount_cents,currency,status,paid_at)
		VALUES($1,$2,'apple',$3,$3,$4,$5,$6,$7)
		ON CONFLICT(provider,transaction_id) DO UPDATE SET status=excluded.status,updated_at=now()
		RETURNING public_id::text,$8,provider::text,amount_cents,currency,status::text,COALESCE(failure_code,''),transaction_id,paid_at,created_at`,
		userID, p.ID, t.TransactionID, p.PriceCents, p.Currency, map[bool]string{true: "refunded", false: "paid"}[t.RevokedAt != nil], t.PurchaseAt, p.Code).
		Scan(&o.PublicID, &o.ProductCode, &o.Provider, &o.AmountCents, &o.Currency, &o.Status, &o.FailureCode, &o.TransactionID, &o.PaidAt, &o.CreatedAt)
	if err != nil {
		return o, err
	}
	if !applyEntitlement {
		return o, tx.Commit(ctx)
	}
	if t.RevokedAt != nil {
		_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id) VALUES($1) ON CONFLICT(user_id) DO UPDATE SET
			tier='glimmer',source_subscription_id=NULL,valid_until=NULL,grace_until=NULL,storage_quota_bytes=$2,ai_quota=0,version=user_entitlements.version+1,updated_at=now()`, userID, domain.FreeStorageQuota)
	} else {
		_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id,tier,source_subscription_id,valid_until,storage_quota_bytes,ai_quota)
			VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id) DO UPDATE SET tier=excluded.tier,source_subscription_id=excluded.source_subscription_id,
			valid_until=excluded.valid_until,storage_quota_bytes=excluded.storage_quota_bytes,ai_quota=excluded.ai_quota,
			version=user_entitlements.version+1,updated_at=now()`, userID, p.Tier, subID, t.ExpiresAt, p.StorageQuotaBytes, p.AIQuota)
	}
	if err != nil {
		return o, err
	}
	return o, tx.Commit(ctx)
}

func shouldApplyAppleTransaction(currentStart, currentEnd time.Time, incoming domain.AppleTransaction) bool {
	if incoming.RevokedAt != nil {
		return true
	}
	if incoming.ExpiresAt.After(currentEnd) {
		return true
	}
	return incoming.ExpiresAt.Equal(currentEnd) && !incoming.PurchaseAt.Before(currentStart)
}

func (r *PG) Cancel(ctx context.Context, userID int64, publicID string) (bool, error) {
	tag, err := r.db.Exec(ctx, `UPDATE subscriptions SET cancel_at_period_end=true,updated_at=now() WHERE user_id=$1 AND public_id=$2
		AND status IN ('trialing','active','grace','past_due')`, userID, publicID)
	return tag.RowsAffected() > 0, err
}

func (r *PG) Subscription(ctx context.Context, userID int64, publicID string) (domain.SubscriptionRef, error) {
	var item domain.SubscriptionRef
	err := r.db.QueryRow(ctx, `SELECT public_id::text,provider::text,COALESCE(external_subscription_id,'')
		FROM subscriptions WHERE user_id=$1 AND public_id=$2 AND status IN ('trialing','active','grace','past_due')`, userID, publicID).
		Scan(&item.PublicID, &item.Provider, &item.ExternalSubscriptionID)
	if errors.Is(err, pgx.ErrNoRows) {
		return item, ErrNotFound
	}
	return item, err
}

func (r *PG) SetAppleCancelAtPeriodEnd(ctx context.Context, userID int64, originalID string, cancelAtPeriodEnd bool) error {
	_, err := r.db.Exec(ctx, `UPDATE subscriptions SET cancel_at_period_end=$3,updated_at=now()
		WHERE user_id=$1 AND provider='apple' AND external_subscription_id=$2`, userID, originalID, cancelAtPeriodEnd)
	return err
}

func (r *PG) CancelProviderAgreement(ctx context.Context, provider, agreementID string) error {
	_, err := r.db.Exec(ctx, `UPDATE subscriptions SET cancel_at_period_end=true,updated_at=now()
		WHERE provider::text=$1 AND external_subscription_id=$2 AND status IN ('trialing','active','grace','past_due')`, provider, agreementID)
	return err
}

func (r *PG) RevokeProviderTransaction(ctx context.Context, provider, transactionID string, refundedAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, provider+":"+transactionID); err != nil {
		return err
	}
	applied, err := applyProviderRefundTx(ctx, tx, provider, transactionID, refundedAt)
	if err != nil {
		return err
	}
	if !applied {
		_, err = tx.Exec(ctx, `INSERT INTO pending_payment_refunds(provider,transaction_id,refunded_at)
			VALUES($1,$2,$3) ON CONFLICT(provider,transaction_id) DO UPDATE SET refunded_at=GREATEST(pending_payment_refunds.refunded_at,excluded.refunded_at)`,
			provider, transactionID, refundedAt)
		if err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func applyProviderRefundTx(ctx context.Context, tx pgx.Tx, provider, transactionID string, refundedAt time.Time) (bool, error) {
	var userID int64
	err := tx.QueryRow(ctx, `UPDATE payment_orders SET status='refunded',refunded_at=$3,updated_at=now()
		WHERE provider::text=$1 AND transaction_id=$2 RETURNING user_id`, provider, transactionID, refundedAt).Scan(&userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	_, err = tx.Exec(ctx, `UPDATE subscriptions SET status='revoked',updated_at=now() WHERE id=(
		SELECT source_subscription_id FROM user_entitlements WHERE user_id=$1)`, userID)
	if err != nil {
		return false, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id) VALUES($1) ON CONFLICT(user_id) DO UPDATE SET
		tier='glimmer',source_subscription_id=NULL,valid_until=NULL,grace_until=NULL,storage_quota_bytes=$2,ai_quota=0,
		version=user_entitlements.version+1,updated_at=now()`, userID, domain.FreeStorageQuota)
	if err != nil {
		return false, err
	}
	_, err = tx.Exec(ctx, `DELETE FROM pending_payment_refunds WHERE provider::text=$1 AND transaction_id=$2`, provider, transactionID)
	return true, err
}

func (r *PG) RecordEvent(ctx context.Context, provider, eventID, eventType string, encrypted []byte, hash string) (bool, error) {
	var claimed bool
	err := r.db.QueryRow(ctx, `INSERT INTO payment_events(provider,external_event_id,event_type,payload_encrypted,payload_hash,status,processed_at)
		VALUES($1,$2,$3,$4,$5,'processing',now())
		ON CONFLICT(provider,external_event_id) DO UPDATE SET status='processing',error_message=NULL,processed_at=now()
		WHERE payment_events.status IN ('received','failed')
			OR (payment_events.status='processing' AND payment_events.processed_at<now()-interval '5 minutes')
		RETURNING true`, provider, eventID, eventType, encrypted, hash).Scan(&claimed)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return claimed, err
}

func (r *PG) MarkEvent(ctx context.Context, provider, eventID, status, message string) error {
	_, err := r.db.Exec(ctx, `UPDATE payment_events SET status=$3,error_message=NULLIF($4,''),processed_at=now()
		WHERE provider=$1 AND external_event_id=$2`, provider, eventID, status, message)
	return err
}

func (r *PG) MarkProviderProductsVerified(ctx context.Context, provider string, externalIDs []string) error {
	_, err := r.db.Exec(ctx, `UPDATE billing_provider_products SET enabled=false,verified_at=NULL WHERE provider::text=$1`, provider)
	if err != nil {
		return err
	}
	if len(externalIDs) == 0 {
		return nil
	}
	_, err = r.db.Exec(ctx, `UPDATE billing_provider_products SET enabled=true,verified_at=now() WHERE provider::text=$1 AND external_product_id=ANY($2)`, provider, externalIDs)
	return err
}

// ClaimDueRenewals leases due rows for ten minutes. Concurrent workers use
// SKIP LOCKED, while the lease also protects against a worker crash.
func (r *PG) ClaimDueRenewals(ctx context.Context, provider string, limit int) ([]domain.RenewalCandidate, error) {
	if limit <= 0 || limit > 100 {
		limit = 25
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	rows, err := tx.Query(ctx, `SELECT s.id,s.user_id,s.external_subscription_id,s.current_period_start,s.current_period_end,s.retry_count,
		p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,p.storage_quota_bytes,p.ai_quota
		FROM subscriptions s JOIN billing_products p ON p.id=s.product_id
		WHERE s.provider::text=$1 AND s.status IN ('trialing','active','past_due','grace') AND s.cancel_at_period_end=false
		AND s.current_period_end<=now() AND COALESCE(s.next_retry_at,s.current_period_end)<=now()
		ORDER BY COALESCE(s.next_retry_at,s.current_period_end) FOR UPDATE OF s SKIP LOCKED LIMIT $2`, provider, limit)
	if err != nil {
		return nil, err
	}
	var items []domain.RenewalCandidate
	for rows.Next() {
		var c domain.RenewalCandidate
		if err = rows.Scan(&c.SubscriptionID, &c.UserID, &c.ExternalSubscriptionID, &c.PeriodStart, &c.PeriodEnd, &c.RetryCount,
			&c.Product.ID, &c.Product.Code, &c.Product.Tier, &c.Product.Period, &c.Product.PriceCents, &c.Product.Currency,
			&c.Product.TrialDays, &c.Product.StorageQuotaBytes, &c.Product.AIQuota); err != nil {
			rows.Close()
			return nil, err
		}
		c.Provider = provider
		items = append(items, c)
	}
	if err = rows.Err(); err != nil {
		rows.Close()
		return nil, err
	}
	rows.Close()
	for _, c := range items {
		if _, err = tx.Exec(ctx, `UPDATE subscriptions SET next_retry_at=now()+interval '10 minutes',updated_at=now() WHERE id=$1`, c.SubscriptionID); err != nil {
			return nil, err
		}
	}
	return items, tx.Commit(ctx)
}

func (r *PG) DueRenewals(ctx context.Context, provider string, limit int) ([]domain.RenewalCandidate, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `SELECT s.id,s.user_id,s.external_subscription_id,s.current_period_start,s.current_period_end,s.retry_count,
		p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,p.storage_quota_bytes,p.ai_quota
		FROM subscriptions s JOIN billing_products p ON p.id=s.product_id
		WHERE s.provider::text=$1 AND s.status IN ('trialing','active','past_due','grace') AND s.cancel_at_period_end=false
		AND s.current_period_end<=now() ORDER BY s.current_period_end LIMIT $2`, provider, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []domain.RenewalCandidate
	for rows.Next() {
		var c domain.RenewalCandidate
		if err = rows.Scan(&c.SubscriptionID, &c.UserID, &c.ExternalSubscriptionID, &c.PeriodStart, &c.PeriodEnd, &c.RetryCount,
			&c.Product.ID, &c.Product.Code, &c.Product.Tier, &c.Product.Period, &c.Product.PriceCents, &c.Product.Currency,
			&c.Product.TrialDays, &c.Product.StorageQuotaBytes, &c.Product.AIQuota); err != nil {
			return nil, err
		}
		c.Provider = provider
		items = append(items, c)
	}
	return items, rows.Err()
}

func (r *PG) CompleteRenewal(ctx context.Context, c domain.RenewalCandidate, transactionID string, paidAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, c.SubscriptionID); err != nil {
		return err
	}
	var transactionExists bool
	if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM payment_orders WHERE provider::text=$1 AND transaction_id=$2)`, c.Provider, transactionID).Scan(&transactionExists); err != nil {
		return err
	}
	if transactionExists {
		return tx.Commit(ctx)
	}
	periodEnd := PeriodForProduct(c.Product, c.PeriodEnd)
	var initialOrderID int64
	err = tx.QueryRow(ctx, `SELECT id FROM payment_orders WHERE user_id=$1 AND provider::text=$2 AND external_order_id=$3
		AND status IN ('created','pending') ORDER BY created_at LIMIT 1 FOR UPDATE`, c.UserID, c.Provider, c.ExternalSubscriptionID).Scan(&initialOrderID)
	if errors.Is(err, pgx.ErrNoRows) {
		_, err = tx.Exec(ctx, `INSERT INTO payment_orders(user_id,product_id,provider,client_request_id,transaction_id,amount_cents,currency,status,paid_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,'paid',$8) ON CONFLICT(provider,transaction_id) DO NOTHING`, c.UserID, c.Product.ID,
			c.Provider, "renewal:"+transactionID, transactionID, c.Product.PriceCents, c.Product.Currency, paidAt)
	} else if err == nil {
		_, err = tx.Exec(ctx, `UPDATE payment_orders SET transaction_id=$2,status='paid',paid_at=$3,failure_code=NULL,updated_at=now() WHERE id=$1`, initialOrderID, transactionID, paidAt)
	}
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE subscriptions SET status='active',current_period_start=$2,current_period_end=$3,
		retry_count=0,next_retry_at=$3,grace_until=NULL,updated_at=now() WHERE id=$1`, c.SubscriptionID, c.PeriodEnd, periodEnd)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id,tier,source_subscription_id,valid_until,storage_quota_bytes,ai_quota)
		VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id) DO UPDATE SET tier=excluded.tier,
		source_subscription_id=excluded.source_subscription_id,valid_until=excluded.valid_until,grace_until=NULL,
		storage_quota_bytes=excluded.storage_quota_bytes,ai_quota=excluded.ai_quota,version=user_entitlements.version+1,updated_at=now()`,
		c.UserID, c.Product.Tier, c.SubscriptionID, periodEnd, c.Product.StorageQuotaBytes, c.Product.AIQuota)
	if err != nil {
		return err
	}
	var pendingRefundAt time.Time
	err = tx.QueryRow(ctx, `SELECT refunded_at FROM pending_payment_refunds WHERE provider::text=$1 AND transaction_id=$2`,
		c.Provider, transactionID).Scan(&pendingRefundAt)
	if err == nil {
		if _, err = applyProviderRefundTx(ctx, tx, c.Provider, transactionID, pendingRefundAt); err != nil {
			return err
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	return tx.Commit(ctx)
}

func (r *PG) RenewalByAgreement(ctx context.Context, provider, agreementID string) (domain.RenewalCandidate, error) {
	var c domain.RenewalCandidate
	err := r.db.QueryRow(ctx, `SELECT s.id,s.user_id,s.external_subscription_id,s.current_period_start,s.current_period_end,s.retry_count,
		p.id,p.code,p.tier::text,p.period::text,p.price_cents,p.currency,p.trial_days,p.storage_quota_bytes,p.ai_quota
		FROM subscriptions s JOIN billing_products p ON p.id=s.product_id
		WHERE s.provider::text=$1 AND s.external_subscription_id=$2`, provider, agreementID).
		Scan(&c.SubscriptionID, &c.UserID, &c.ExternalSubscriptionID, &c.PeriodStart, &c.PeriodEnd, &c.RetryCount,
			&c.Product.ID, &c.Product.Code, &c.Product.Tier, &c.Product.Period, &c.Product.PriceCents, &c.Product.Currency,
			&c.Product.TrialDays, &c.Product.StorageQuotaBytes, &c.Product.AIQuota)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, ErrNotFound
	}
	c.Provider = provider
	return c, err
}

func (r *PG) FailRenewal(ctx context.Context, c domain.RenewalCandidate, code string, now time.Time) error {
	retry := c.RetryCount + 1
	status := "past_due"
	graceUntil := c.PeriodEnd.Add(72 * time.Hour)
	next := now.Add(24 * time.Hour)
	if retry >= 3 {
		status = "grace"
		next = graceUntil
	}
	_, err := r.db.Exec(ctx, `UPDATE subscriptions SET status=$2,retry_count=$3,next_retry_at=$4,grace_until=$5,updated_at=now()
		WHERE id=$1 AND retry_count=$6`, c.SubscriptionID, status, retry, next, graceUntil, c.RetryCount)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(ctx, `UPDATE user_entitlements SET grace_until=$2,version=version+1,updated_at=now()
		WHERE user_id=$1 AND source_subscription_id=$3`, c.UserID, graceUntil, c.SubscriptionID)
	return err
}

func (r *PG) Sweep(ctx context.Context) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	var locked bool
	if err = tx.QueryRow(ctx, `SELECT pg_try_advisory_xact_lock(7249461101)`).Scan(&locked); err != nil || !locked {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE subscriptions SET status='expired',updated_at=now() WHERE
		(status IN ('trialing','active') AND current_period_end<=now() AND (provider='apple' OR cancel_at_period_end=true))
		OR (status IN ('grace','past_due') AND COALESCE(grace_until,current_period_end)<=now())`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE user_entitlements ue SET tier='glimmer',source_subscription_id=NULL,valid_until=NULL,grace_until=NULL,
		storage_quota_bytes=$1,ai_quota=0,version=version+1,updated_at=now() FROM subscriptions s
		WHERE ue.source_subscription_id=s.id AND s.status IN ('expired','revoked')`, domain.FreeStorageQuota); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `DELETE FROM storage_reservations WHERE consumed_at IS NULL AND expires_at<=now()`); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func PeriodForProduct(p domain.Product, start time.Time) time.Time {
	if p.Period == "year" {
		return start.AddDate(1, 0, 0)
	}
	return start.AddDate(0, 1, 0)
}

func (r *PG) ReserveStorage(ctx context.Context, userID int64, objectKey string, bytes int64) error {
	return r.ReserveStorageFor(ctx, userID, objectKey, bytes, 15*time.Minute)
}

func (r *PG) ReserveStorageFor(ctx context.Context, userID int64, objectKey string, bytes int64, ttl time.Duration) error {
	if bytes <= 0 {
		return ErrStorageQuota
	}
	if ttl <= 0 {
		return ErrStorageQuota
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, userID); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `INSERT INTO user_entitlements(user_id) VALUES($1) ON CONFLICT DO NOTHING`, userID); err != nil {
		return err
	}
	var quota, used, reserved int64
	err = tx.QueryRow(ctx, `SELECT CASE WHEN ue.valid_until IS NULL OR ue.valid_until>now() OR ue.grace_until>now() THEN ue.storage_quota_bytes ELSE $2 END,
		COALESCE((SELECT SUM(file_size) FROM media_files WHERE user_id=$1 AND deleted_at IS NULL),0),
		COALESCE((SELECT SUM(bytes) FROM storage_reservations WHERE user_id=$1 AND object_key<>$3 AND consumed_at IS NULL AND expires_at>now()),0)
		FROM user_entitlements ue WHERE ue.user_id=$1`, userID, domain.FreeStorageQuota, objectKey).Scan(&quota, &used, &reserved)
	if err != nil {
		return err
	}
	if used+reserved+bytes > quota {
		return ErrStorageQuota
	}
	tag, err := tx.Exec(ctx, `INSERT INTO storage_reservations(user_id,object_key,bytes,expires_at) VALUES($1,$2,$3,now()+$4::interval)
		ON CONFLICT(object_key) DO UPDATE SET bytes=excluded.bytes,expires_at=excluded.expires_at WHERE storage_reservations.user_id=excluded.user_id AND storage_reservations.consumed_at IS NULL`, userID, objectKey, bytes, ttl.String())
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrStorageQuota
	}
	return tx.Commit(ctx)
}

func (r *PG) ConsumeStorage(ctx context.Context, userID int64, objectKey string) error {
	tag, err := r.db.Exec(ctx, `UPDATE storage_reservations SET consumed_at=now() WHERE user_id=$1 AND object_key=$2 AND consumed_at IS NULL AND expires_at>now()`, userID, objectKey)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrStorageQuota
	}
	return nil
}
func (r *PG) ReleaseStorage(ctx context.Context, userID int64, objectKey string) {
	_, _ = r.db.Exec(ctx, `DELETE FROM storage_reservations WHERE user_id=$1 AND object_key=$2`, userID, objectKey)
}

func (r *PG) ReserveAI(ctx context.Context, userID int64) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, userID); err != nil {
		return err
	}
	var quota int
	var start, end time.Time
	err = tx.QueryRow(ctx, `SELECT ue.ai_quota,COALESCE(s.current_period_start,date_trunc('month',now())),
		COALESCE(s.current_period_end,date_trunc('month',now())+interval '1 month') FROM user_entitlements ue
		LEFT JOIN subscriptions s ON s.id=ue.source_subscription_id WHERE ue.user_id=$1 AND ue.tier='galaxy'
		AND (ue.valid_until>now() OR ue.grace_until>now())`, userID).Scan(&quota, &start, &end)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrEntitlementRequired
	}
	if err != nil {
		return err
	}
	var used int
	err = tx.QueryRow(ctx, `INSERT INTO usage_counters(user_id,metric,period_start,period_end,used) VALUES($1,'ai',$2,$3,1)
		ON CONFLICT(user_id,metric,period_start) DO UPDATE SET used=usage_counters.used+1,updated_at=now() RETURNING used`, userID, start, end).Scan(&used)
	if err != nil {
		return err
	}
	if used > quota {
		return ErrAIQuota
	}
	return tx.Commit(ctx)
}
func (r *PG) ReleaseAI(ctx context.Context, userID int64) {
	_, _ = r.db.Exec(ctx, `UPDATE usage_counters SET used=GREATEST(0,used-1),updated_at=now() WHERE user_id=$1 AND metric='ai' AND now()>=period_start AND now()<period_end`, userID)
}
