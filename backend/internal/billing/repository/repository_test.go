package repository

import (
	"testing"
	"time"

	"xiguang/backend/internal/billing/domain"
)

func TestShouldApplyAppleTransaction(t *testing.T) {
	now := time.Now().UTC()
	currentStart := now
	currentEnd := now.AddDate(0, 1, 0)
	revokedAt := now.Add(time.Hour)

	tests := []struct {
		name     string
		incoming domain.AppleTransaction
		want     bool
	}{
		{name: "new renewal", incoming: domain.AppleTransaction{PurchaseAt: currentEnd, ExpiresAt: currentEnd.AddDate(0, 1, 0)}, want: true},
		{name: "same period upgrade", incoming: domain.AppleTransaction{PurchaseAt: currentStart.Add(time.Hour), ExpiresAt: currentEnd}, want: true},
		{name: "older period", incoming: domain.AppleTransaction{PurchaseAt: currentStart.AddDate(0, -1, 0), ExpiresAt: currentStart}, want: false},
		{name: "older transaction with same expiry", incoming: domain.AppleTransaction{PurchaseAt: currentStart.Add(-time.Second), ExpiresAt: currentEnd}, want: false},
		{name: "historical revoke", incoming: domain.AppleTransaction{PurchaseAt: currentStart.AddDate(0, -1, 0), ExpiresAt: currentStart, RevokedAt: &revokedAt}, want: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := shouldApplyAppleTransaction(currentStart, currentEnd, tt.incoming); got != tt.want {
				t.Fatalf("shouldApplyAppleTransaction() = %v, want %v", got, tt.want)
			}
		})
	}
}
