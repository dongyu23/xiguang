package service

import "xiguang/backend/internal/billing/domain"

var fixedBillingCatalog = []domain.Product{
	{Code: "starlight_month", Tier: "starlight", Period: "month", PriceCents: 1200, Currency: "CNY", TrialDays: 0, StorageQuotaBytes: 20 << 30, AIQuota: 0},
	{Code: "starlight_year", Tier: "starlight", Period: "year", PriceCents: 9800, Currency: "CNY", TrialDays: 7, StorageQuotaBytes: 20 << 30, AIQuota: 0},
	{Code: "galaxy_month", Tier: "galaxy", Period: "month", PriceCents: 2800, Currency: "CNY", TrialDays: 0, StorageQuotaBytes: 100 << 30, AIQuota: 300},
	{Code: "galaxy_year", Tier: "galaxy", Period: "year", PriceCents: 21800, Currency: "CNY", TrialDays: 7, StorageQuotaBytes: 100 << 30, AIQuota: 300},
}

func validateConfiguredCatalog(channel string, products []domain.Product) string {
	status := validateCatalogStructure(channel, products)
	if status != "configured" {
		return status
	}
	for _, product := range products {
		if !product.ProviderEnabled {
			return "products_unverified"
		}
	}
	return "configured"
}

func validateCatalogStructure(channel string, products []domain.Product) string {
	if len(products) != len(fixedBillingCatalog) {
		return "products_incomplete"
	}
	byCode := make(map[string]domain.Product, len(products))
	for _, product := range products {
		if _, duplicated := byCode[product.Code]; duplicated {
			return "products_incomplete"
		}
		byCode[product.Code] = product
	}
	for _, expected := range fixedBillingCatalog {
		actual, ok := byCode[expected.Code]
		if !ok || actual.ExternalProductID == "" {
			return "products_incomplete"
		}
		externalID := "com.xiguang.membership." + expected.Tier + "." + expected.Period
		if actual.Provider != channel || actual.Tier != expected.Tier || actual.Period != expected.Period ||
			actual.PriceCents != expected.PriceCents || actual.Currency != expected.Currency ||
			actual.TrialDays != expected.TrialDays || actual.StorageQuotaBytes != expected.StorageQuotaBytes ||
			actual.AIQuota != expected.AIQuota || actual.ExternalProductID != externalID {
			return "products_mismatch"
		}
	}
	return "configured"
}
