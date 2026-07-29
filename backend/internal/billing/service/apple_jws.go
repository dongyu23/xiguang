package service

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"strings"
	"time"

	"xiguang/backend/internal/billing/domain"
)

var ErrInvalidAppleTransaction = errors.New("invalid_apple_transaction")

type appleHeader struct {
	X5C []string `json:"x5c"`
}

type appleRenewalInfo struct {
	OriginalTransactionID string
	AutoRenewStatus       int
}

func VerifyAppleTransaction(jws, bundleID, environment string) (domain.AppleTransaction, error) {
	return verifyAppleTransactionWithRoots(jws, bundleID, environment, nil)
}

func verifyAppleTransactionWithRoots(jws, bundleID, environment string, roots *x509.CertPool) (domain.AppleTransaction, error) {
	payloadBytes, err := verifyAppleJWSWithRoots(jws, roots)
	if err != nil {
		return domain.AppleTransaction{}, err
	}
	var p struct {
		TransactionID, OriginalTransactionID, ProductID, BundleID, Environment, AppAccountToken string
		PurchaseDate, ExpiresDate, RevocationDate                                               int64
		OfferType                                                                               int
	}
	if json.Unmarshal(payloadBytes, &p) != nil || p.TransactionID == "" || p.OriginalTransactionID == "" || p.ProductID == "" {
		return domain.AppleTransaction{}, ErrInvalidAppleTransaction
	}
	if p.BundleID != bundleID || !strings.EqualFold(p.Environment, environment) {
		return domain.AppleTransaction{}, ErrInvalidAppleTransaction
	}
	t := domain.AppleTransaction{TransactionID: p.TransactionID, OriginalTransactionID: p.OriginalTransactionID, ProductID: p.ProductID, BundleID: p.BundleID, Environment: p.Environment, AppAccountToken: p.AppAccountToken, OfferType: p.OfferType,
		PurchaseAt: time.UnixMilli(p.PurchaseDate), ExpiresAt: time.UnixMilli(p.ExpiresDate)}
	if p.RevocationDate > 0 {
		v := time.UnixMilli(p.RevocationDate)
		t.RevokedAt = &v
	}
	if t.ExpiresAt.IsZero() {
		return domain.AppleTransaction{}, ErrInvalidAppleTransaction
	}
	return t, nil
}

func VerifyAppleRenewalInfo(jws, bundleID, environment string) (appleRenewalInfo, error) {
	return verifyAppleRenewalInfoWithRoots(jws, bundleID, environment, nil)
}

func verifyAppleRenewalInfoWithRoots(jws, bundleID, environment string, roots *x509.CertPool) (appleRenewalInfo, error) {
	payloadBytes, err := verifyAppleJWSWithRoots(jws, roots)
	if err != nil {
		return appleRenewalInfo{}, err
	}
	var payload struct {
		OriginalTransactionID string `json:"originalTransactionId"`
		AutoRenewStatus       int    `json:"autoRenewStatus"`
		BundleID              string `json:"bundleId"`
		Environment           string `json:"environment"`
	}
	if json.Unmarshal(payloadBytes, &payload) != nil || payload.OriginalTransactionID == "" ||
		payload.BundleID != bundleID || !strings.EqualFold(payload.Environment, environment) ||
		(payload.AutoRenewStatus != 0 && payload.AutoRenewStatus != 1) {
		return appleRenewalInfo{}, ErrInvalidAppleTransaction
	}
	return appleRenewalInfo{OriginalTransactionID: payload.OriginalTransactionID, AutoRenewStatus: payload.AutoRenewStatus}, nil
}

func verifyAppleJWS(jws string) ([]byte, error) {
	return verifyAppleJWSWithRoots(jws, nil)
}

func verifyAppleJWSWithRoots(jws string, roots *x509.CertPool) ([]byte, error) {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return nil, ErrInvalidAppleTransaction
	}
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, ErrInvalidAppleTransaction
	}
	var h appleHeader
	if json.Unmarshal(headerBytes, &h) != nil || len(h.X5C) == 0 {
		return nil, ErrInvalidAppleTransaction
	}
	certs := make([]*x509.Certificate, 0, len(h.X5C))
	for _, encoded := range h.X5C {
		der, e := base64.StdEncoding.DecodeString(encoded)
		if e != nil {
			return nil, ErrInvalidAppleTransaction
		}
		cert, e := x509.ParseCertificate(der)
		if e != nil {
			return nil, ErrInvalidAppleTransaction
		}
		certs = append(certs, cert)
	}
	intermediates := x509.NewCertPool()
	for _, cert := range certs[1:] {
		intermediates.AddCert(cert)
	}
	if _, err = certs[0].Verify(x509.VerifyOptions{Roots: roots, Intermediates: intermediates, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		return nil, ErrInvalidAppleTransaction
	}
	pub, ok := certs[0].PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, ErrInvalidAppleTransaction
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || len(sig)%2 != 0 {
		return nil, ErrInvalidAppleTransaction
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	half := len(sig) / 2
	if !ecdsa.Verify(pub, digest[:], new(big.Int).SetBytes(sig[:half]), new(big.Int).SetBytes(sig[half:])) {
		return nil, ErrInvalidAppleTransaction
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, ErrInvalidAppleTransaction
	}
	return payloadBytes, nil
}
