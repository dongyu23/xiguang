package service

import (
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"strings"
	"testing"
	"time"

	"xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/infra/config"
)

func TestEncryptPayloadDoesNotStorePlaintext(t *testing.T) {
	payload := []byte(`{"transaction":"private"}`)
	encrypted, hash, err := encryptPayload("01234567890123456789012345678901", payload)
	if err != nil {
		t.Fatal(err)
	}
	if string(encrypted) == string(payload) {
		t.Fatal("payload was not encrypted")
	}
	sum := sha256.Sum256(payload)
	if hash != base64HashHex(sum[:]) {
		t.Fatalf("unexpected hash %s", hash)
	}
}

func TestParseCNYCents(t *testing.T) {
	tests := map[string]int{
		"12":    1200,
		"12.0":  1200,
		"12.00": 1200,
		"0.01":  1,
		"218":   21800,
	}
	for input, want := range tests {
		got, err := parseCNYCents(input)
		if err != nil || got != want {
			t.Fatalf("parseCNYCents(%q) = %d, %v; want %d", input, got, err, want)
		}
	}
	for _, input := range []string{"", "-1", "12.001", "1.2.3", "CNY12"} {
		if _, err := parseCNYCents(input); err == nil {
			t.Fatalf("parseCNYCents(%q) accepted invalid amount", input)
		}
	}
}

func TestOfflineEntitlementSnapshotIsEd25519Signed(t *testing.T) {
	service := &Service{cfg: config.Config{PaymentEncryptionKey: "01234567890123456789012345678901"}}
	token, encodedPublicKey, err := service.signOfflineEntitlement(42, domain.Entitlement{Tier: "starlight", Status: "active", EntitlementVersion: 7})
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("invalid snapshot token: %s", token)
	}
	publicKey, err := base64.RawURLEncoding.DecodeString(encodedPublicKey)
	if err != nil {
		t.Fatal(err)
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		t.Fatal(err)
	}
	if !ed25519.Verify(ed25519.PublicKey(publicKey), []byte(parts[0]+"."+parts[1]), signature) {
		t.Fatal("offline entitlement signature did not verify")
	}
	payload, _ := base64.RawURLEncoding.DecodeString(parts[1])
	if !strings.Contains(string(payload), `"tier":"starlight"`) || !strings.Contains(string(payload), `"exp":`) {
		t.Fatalf("snapshot claims are incomplete: %s", payload)
	}
}

func base64HashHex(value []byte) string {
	const digits = "0123456789abcdef"
	out := make([]byte, len(value)*2)
	for i, b := range value {
		out[i*2] = digits[b>>4]
		out[i*2+1] = digits[b&15]
	}
	return string(out)
}

func TestVerifyAppleJWSRejectsTampering(t *testing.T) {
	rootKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	now := time.Now()
	rootTemplate := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "test root"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign}
	rootDER, _ := x509.CreateCertificate(rand.Reader, rootTemplate, rootTemplate, &rootKey.PublicKey, rootKey)
	rootCert, _ := x509.ParseCertificate(rootDER)
	leafKey, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	leafTemplate := &x509.Certificate{SerialNumber: big.NewInt(2), Subject: pkix.Name{CommonName: "leaf"}, NotBefore: now.Add(-time.Hour), NotAfter: now.Add(time.Hour), KeyUsage: x509.KeyUsageDigitalSignature}
	leafDER, _ := x509.CreateCertificate(rand.Reader, leafTemplate, rootCert, &leafKey.PublicKey, rootKey)
	header, _ := json.Marshal(map[string]any{"alg": "ES256", "x5c": []string{base64.StdEncoding.EncodeToString(leafDER), base64.StdEncoding.EncodeToString(rootDER)}})
	payload := []byte(`{"ok":true}`)
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	digest := sha256.Sum256([]byte(unsigned))
	r, s, _ := ecdsa.Sign(rand.Reader, leafKey, digest[:])
	signature := append(padBigInt(r, 32), padBigInt(s, 32)...)
	jws := unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
	roots := x509.NewCertPool()
	roots.AddCert(rootCert)
	verified, err := verifyAppleJWSWithRoots(jws, roots)
	if err != nil {
		t.Fatal(err)
	}
	if string(verified) != string(payload) {
		t.Fatal("payload mismatch")
	}
	if _, err = verifyAppleJWSWithRoots(jws+"x", roots); err == nil {
		t.Fatal("tampered JWS accepted")
	}
}
