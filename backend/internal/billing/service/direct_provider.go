package service

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"xiguang/backend/internal/billing/domain"
)

func renewalOutTradeNo(candidate domain.RenewalCandidate) string {
	return fmt.Sprintf("xg-%d-%d", candidate.SubscriptionID, candidate.PeriodEnd.Unix())
}

// DirectDebitProvider isolates qualification-specific WeChat/Alipay APIs from
// the billing state machine. SDK responses never grant entitlements directly.
type DirectDebitProvider interface {
	Name() string
	VerifyProducts(context.Context, []domain.Product) ([]string, error)
	StartAgreement(context.Context, domain.Order, domain.Product) (map[string]any, error)
	Charge(context.Context, domain.RenewalCandidate) (transactionID string, paidAt time.Time, err error)
	QueryCharge(context.Context, domain.RenewalCandidate) (transactionID string, paidAt time.Time, found bool, err error)
	Cancel(context.Context, string) error
}

func (s *Service) RunDirectRenewals(ctx context.Context) error {
	for name, provider := range s.providers {
		items, err := s.repo.ClaimDueRenewals(ctx, name, 25)
		if err != nil {
			s.metrics.inc("xiguang_payment_renewal_events_total", labels("provider", name, "result", "claim_failed"))
			return err
		}
		for _, item := range items {
			transactionID, paidAt, chargeErr := provider.Charge(ctx, item)
			if chargeErr != nil {
				s.metrics.inc("xiguang_payment_renewal_events_total", labels("provider", name, "result", "charge_failed"))
				slog.WarnContext(ctx, "payment renewal failed", "provider", name, "subscription_id", item.SubscriptionID, "error_code", ChannelError(chargeErr))
				if err = s.repo.FailRenewal(ctx, item, ChannelError(chargeErr), time.Now().UTC()); err != nil {
					return err
				}
				continue
			}
			if transactionID == "" || paidAt.IsZero() {
				s.metrics.inc("xiguang_payment_renewal_events_total", labels("provider", name, "result", "invalid_result"))
				if err = s.repo.FailRenewal(ctx, item, "invalid_provider_result", time.Now().UTC()); err != nil {
					return err
				}
				continue
			}
			if err = s.repo.CompleteRenewal(ctx, item, transactionID, paidAt); err != nil {
				s.metrics.inc("xiguang_payment_renewal_events_total", labels("provider", name, "result", "complete_failed"))
				return err
			}
			s.metrics.inc("xiguang_payment_renewal_events_total", labels("provider", name, "result", "paid"))
		}
	}
	return nil
}

func (s *Service) ReconcileDirect(ctx context.Context) error {
	for name, provider := range s.providers {
		items, err := s.repo.DueRenewals(ctx, name, 100)
		if err != nil {
			s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", name, "result", "query_failed"))
			return err
		}
		for _, item := range items {
			transactionID, paidAt, found, queryErr := provider.QueryCharge(ctx, item)
			if queryErr != nil {
				s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", name, "result", "provider_failed"))
				continue
			}
			if found {
				if err = s.repo.CompleteRenewal(ctx, item, transactionID, paidAt); err != nil {
					s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", name, "result", "repair_failed"))
					return err
				}
				s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", name, "result", "repaired"))
			}
		}
	}
	return nil
}
