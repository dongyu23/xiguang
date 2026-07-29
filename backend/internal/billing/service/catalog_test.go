package service

import (
	"errors"
	"testing"

	"xiguang/backend/internal/billing/domain"
)

func configuredProducts(channel string) []domain.Product {
	products := make([]domain.Product, len(fixedBillingCatalog))
	for index, expected := range fixedBillingCatalog {
		products[index] = expected
		products[index].Provider = channel
		products[index].ProviderEnabled = true
		products[index].ExternalProductID = "com.xiguang.membership." + expected.Tier + "." + expected.Period
	}
	return products
}

func TestChannelErrorNeverReturnsProviderPayload(t *testing.T) {
	err := errors.New(`Alipay HTTP 400: {"out_trade_no":"full-order-number","sub_msg":"denied"}`)
	if code := ChannelError(err); code != "provider_http_error" {
		t.Fatalf("channel error = %q", code)
	}
}

func TestValidateConfiguredCatalogRequiresExactFixedCatalog(t *testing.T) {
	products := configuredProducts("apple")
	if status := validateConfiguredCatalog("apple", products); status != "configured" {
		t.Fatalf("complete catalog status = %q", status)
	}
	products[0].ProviderEnabled = false
	if status := validateCatalogStructure("apple", products); status != "configured" {
		t.Fatalf("disabled product changed structural status = %q", status)
	}
	products[0].ProviderEnabled = true
	if status := validateConfiguredCatalog("apple", products[:3]); status != "products_incomplete" {
		t.Fatalf("missing product status = %q", status)
	}
	products = configuredProducts("apple")
	products[0].PriceCents++
	if status := validateConfiguredCatalog("apple", products); status != "products_mismatch" {
		t.Fatalf("tampered product status = %q", status)
	}
	products = configuredProducts("apple")
	products[0].ProviderEnabled = false
	if status := validateConfiguredCatalog("apple", products); status != "products_unverified" {
		t.Fatalf("unverified product status = %q", status)
	}
}
