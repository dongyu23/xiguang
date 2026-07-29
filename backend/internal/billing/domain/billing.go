package domain

import "time"

const FreeStorageQuota int64 = 1 << 30

func TierAllows(tier, required string) bool {
	rank := map[string]int{"glimmer": 0, "starlight": 1, "galaxy": 2}
	return rank[tier] >= rank[required]
}

type Product struct {
	ID                int64  `json:"-"`
	Code              string `json:"code"`
	Tier              string `json:"tier"`
	Period            string `json:"period"`
	PriceCents        int    `json:"price_cents"`
	Currency          string `json:"currency"`
	TrialDays         int    `json:"trial_days"`
	StorageQuotaBytes int64  `json:"storage_quota_bytes"`
	AIQuota           int    `json:"ai_quota"`
	ExternalProductID string `json:"external_product_id,omitempty"`
	Provider          string `json:"provider"`
	ProviderEnabled   bool   `json:"provider_enabled"`
}

type Entitlement struct {
	Tier               string     `json:"tier"`
	Status             string     `json:"status"`
	Provider           string     `json:"provider,omitempty"`
	ProductCode        string     `json:"product_code,omitempty"`
	SubscriptionID     string     `json:"subscription_id,omitempty"`
	ValidUntil         *time.Time `json:"valid_until,omitempty"`
	GraceUntil         *time.Time `json:"grace_until,omitempty"`
	CancelAtPeriodEnd  bool       `json:"cancel_at_period_end"`
	StorageQuotaBytes  int64      `json:"storage_quota_bytes"`
	StorageUsedBytes   int64      `json:"storage_used_bytes"`
	AIQuota            int        `json:"ai_quota"`
	AIUsed             int        `json:"ai_used"`
	EntitlementVersion int64      `json:"version"`
	OfflineSnapshot    string     `json:"offline_snapshot,omitempty"`
	OfflinePublicKey   string     `json:"offline_public_key,omitempty"`
}

type Order struct {
	PublicID      string     `json:"id"`
	ProductCode   string     `json:"product_code"`
	Provider      string     `json:"provider"`
	AmountCents   int        `json:"amount_cents"`
	Currency      string     `json:"currency"`
	Status        string     `json:"status"`
	FailureCode   string     `json:"failure_code,omitempty"`
	TransactionID string     `json:"transaction_id,omitempty"`
	PaidAt        *time.Time `json:"paid_at,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

type CreateSubscriptionRequest struct {
	Provider        string `json:"provider"`
	ProductCode     string `json:"product_code"`
	ClientRequestID string `json:"client_request_id"`
}

type CreateSubscriptionResult struct {
	Order      Order          `json:"order"`
	SDKPayload map[string]any `json:"sdk_payload,omitempty"`
}

type AppleTransaction struct {
	TransactionID         string
	OriginalTransactionID string
	ProductID             string
	BundleID              string
	Environment           string
	AppAccountToken       string
	OfferType             int
	PurchaseAt            time.Time
	ExpiresAt             time.Time
	RevokedAt             *time.Time
}

// AppleSubscriptionRef is the minimum local state needed for a Server API reconciliation.
type AppleSubscriptionRef struct {
	UserID                int64
	OriginalTransactionID string
}

// ProviderPayment is the normalized result of a verified WeChat or Alipay charge.
type ProviderPayment struct {
	Provider               string
	OrderID                string
	TransactionID          string
	ExternalSubscriptionID string
	PayerSubjectHash       string
	PaidAt                 time.Time
	PeriodStart            time.Time
	PeriodEnd              time.Time
	RefundedAt             *time.Time
}

// RenewalCandidate is leased before calling a provider to prevent duplicate charges.
type RenewalCandidate struct {
	SubscriptionID         int64
	UserID                 int64
	Product                Product
	Provider               string
	ExternalSubscriptionID string
	PeriodStart            time.Time
	PeriodEnd              time.Time
	RetryCount             int
}

type SubscriptionRef struct {
	PublicID               string
	Provider               string
	ExternalSubscriptionID string
}

type Readiness struct {
	Enabled  bool              `json:"enabled"`
	Ready    bool              `json:"ready"`
	Mode     string            `json:"mode"`
	Catalog  string            `json:"catalog"`
	Channels map[string]string `json:"channels"`
}
