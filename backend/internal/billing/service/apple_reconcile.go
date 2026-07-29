package service

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// ReconcileApple uses the App Store Server API as the daily source of truth.
// Notifications remain the fast path; reconciliation repairs delayed or lost ones.
func (s *Service) ReconcileApple(ctx context.Context) error {
	if !s.cfg.PaymentEnabled || !s.channelEnabled("apple") {
		return nil
	}
	token, err := appStoreServerToken(s.cfg.AppleIssuerID, s.cfg.AppleKeyID, s.cfg.ApplePrivateKey, s.cfg.AppleBundleID)
	if err != nil {
		s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "token_failed"))
		return err
	}
	items, err := s.repo.ActiveAppleSubscriptions(ctx)
	if err != nil {
		s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "query_failed"))
		return err
	}
	baseURL := "https://api.storekit-sandbox.itunes.apple.com"
	if s.cfg.PaymentEnvironment == "production" {
		baseURL = "https://api.storekit.itunes.apple.com"
	}
	client := http.Client{Timeout: 20 * time.Second}
	for _, item := range items {
		endpoint := baseURL + "/inApps/v1/subscriptions/" + url.PathEscape(item.OriginalTransactionID)
		var response struct {
			Data []struct {
				LastTransactions []struct {
					SignedTransactionInfo string `json:"signedTransactionInfo"`
					SignedRenewalInfo     string `json:"signedRenewalInfo"`
				} `json:"lastTransactions"`
			} `json:"data"`
		}
		if err := fetchAppleJSON(ctx, &client, endpoint, token, &response); err != nil {
			s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "provider_failed"))
			return fmt.Errorf("reconcile Apple subscription %s: %w", item.OriginalTransactionID, err)
		}
		for _, group := range response.Data {
			for _, latest := range group.LastTransactions {
				if latest.SignedTransactionInfo == "" {
					continue
				}
				environment := map[bool]string{true: "Production", false: "Sandbox"}[s.cfg.PaymentEnvironment == "production"]
				transaction, err := verifyAppleTransactionWithRoots(latest.SignedTransactionInfo, s.cfg.AppleBundleID, environment, s.appleJWSRoots)
				if err != nil || transaction.OriginalTransactionID != item.OriginalTransactionID {
					s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "mismatch"))
					return ErrInvalidAppleTransaction
				}
				product, err := s.repo.ProductByExternalID(ctx, "apple", transaction.ProductID)
				if err != nil || !product.ProviderEnabled {
					return ErrChannelUnavailable
				}
				if _, err = s.repo.ApplyAppleTransaction(ctx, item.UserID, product, transaction); err != nil {
					s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "repair_failed"))
					return err
				}
				s.metrics.inc("xiguang_payment_reconciliation_events_total", labels("provider", "apple", "result", "verified"))
				if latest.SignedRenewalInfo != "" {
					renewal, renewalErr := verifyAppleRenewalInfoWithRoots(latest.SignedRenewalInfo, s.cfg.AppleBundleID, environment, s.appleJWSRoots)
					if renewalErr != nil || renewal.OriginalTransactionID != item.OriginalTransactionID {
						return ErrInvalidAppleTransaction
					}
					if err = s.repo.SetAppleCancelAtPeriodEnd(ctx, item.UserID, renewal.OriginalTransactionID, renewal.AutoRenewStatus == 0); err != nil {
						return err
					}
				}
			}
		}
	}
	return nil
}
