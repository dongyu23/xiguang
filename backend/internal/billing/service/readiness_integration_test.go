package service

import (
	"context"
	"testing"
	"time"

	"xiguang/backend/internal/infra/config"
)

type providerProductState struct {
	productID  int64
	externalID string
	enabled    bool
	verifiedAt *time.Time
}

func TestReadinessFailsClosedForMissingOrTamperedProducts(t *testing.T) {
	repo, pool, _ := serviceIntegrationRepo(t)
	rows, err := pool.Query(t.Context(), `SELECT product_id,external_product_id,enabled,verified_at
		FROM billing_provider_products WHERE provider='apple' ORDER BY product_id`)
	if err != nil {
		t.Fatal(err)
	}
	var original []providerProductState
	for rows.Next() {
		var item providerProductState
		if err = rows.Scan(&item.productID, &item.externalID, &item.enabled, &item.verifiedAt); err != nil {
			rows.Close()
			t.Fatal(err)
		}
		original = append(original, item)
	}
	rows.Close()
	if err = rows.Err(); err != nil {
		t.Fatal(err)
	}
	if len(original) != len(fixedBillingCatalog) {
		t.Fatalf("Apple mappings = %d, want %d", len(original), len(fixedBillingCatalog))
	}
	var originalPrice int
	if err = pool.QueryRow(t.Context(), `SELECT price_cents FROM billing_products WHERE code='starlight_month'`).Scan(&originalPrice); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `UPDATE billing_products SET price_cents=$1 WHERE code='starlight_month'`, originalPrice)
		for _, item := range original {
			_, _ = pool.Exec(context.Background(), `INSERT INTO billing_provider_products(product_id,provider,external_product_id,enabled,verified_at)
				VALUES($1,'apple',$2,$3,$4) ON CONFLICT(product_id,provider) DO UPDATE SET
				external_product_id=excluded.external_product_id,enabled=excluded.enabled,verified_at=excluded.verified_at`,
				item.productID, item.externalID, item.enabled, item.verifiedAt)
		}
	})

	if _, err = pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now() WHERE provider='apple'`); err != nil {
		t.Fatal(err)
	}
	service := New(repo, config.Config{PaymentEnabled: true, PaymentEnvironment: "sandbox", PaymentChannels: []string{"apple"}})
	if err = service.PrepareInitialization(t.Context()); err != nil {
		t.Fatal(err)
	}
	if readiness := service.Readiness(t.Context()); readiness.Ready || readiness.Channels["apple"] != "products_unverified" {
		t.Fatalf("initialization preparation did not fail closed: %+v", readiness)
	}
	service.initialized.Store(true)
	if _, err = pool.Exec(t.Context(), `UPDATE billing_provider_products SET enabled=true,verified_at=now() WHERE provider='apple'`); err != nil {
		t.Fatal(err)
	}
	if readiness := service.Readiness(t.Context()); !readiness.Ready {
		t.Fatalf("complete catalog was not ready: %+v", readiness)
	}

	missing := original[0]
	if _, err = pool.Exec(t.Context(), `DELETE FROM billing_provider_products WHERE product_id=$1 AND provider='apple'`, missing.productID); err != nil {
		t.Fatal(err)
	}
	readiness := service.Readiness(t.Context())
	if readiness.Ready || readiness.Channels["apple"] != "products_incomplete" {
		t.Fatalf("missing mapping readiness = %+v", readiness)
	}
	if _, err = pool.Exec(t.Context(), `INSERT INTO billing_provider_products(product_id,provider,external_product_id,enabled,verified_at)
		VALUES($1,'apple',$2,true,now())`, missing.productID, missing.externalID); err != nil {
		t.Fatal(err)
	}

	if _, err = pool.Exec(t.Context(), `UPDATE billing_products SET price_cents=1 WHERE code='starlight_month'`); err != nil {
		t.Fatal(err)
	}
	readiness = service.Readiness(t.Context())
	if readiness.Ready || readiness.Channels["apple"] != "products_mismatch" {
		t.Fatalf("tampered product readiness = %+v", readiness)
	}
}
