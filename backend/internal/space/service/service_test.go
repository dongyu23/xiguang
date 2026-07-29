package service

import (
	"context"
	"testing"

	billingdomain "xiguang/backend/internal/billing/domain"
	"xiguang/backend/internal/space/domain"
)

type memoryRepo struct{ config domain.Config }

func (r *memoryRepo) Config(context.Context, int64) (domain.Config, error) { return r.config, nil }
func (r *memoryRepo) Update(_ context.Context, _ int64, config domain.Config) (domain.Config, error) {
	r.config = config
	return config, nil
}

type entitlementStub struct{ tier string }

func (s entitlementStub) Entitlement(context.Context, int64) (billingdomain.Entitlement, error) {
	return billingdomain.Entitlement{Tier: s.tier}, nil
}

func TestPaidThemeRequiresStarlight(t *testing.T) {
	repo := &memoryRepo{config: domain.Config{Theme: domain.ThemeMorningMist, BreathingMotion: true}}
	glimmer := New(repo, entitlementStub{tier: "glimmer"})
	if _, err := glimmer.UpdateConfig(context.Background(), 1, domain.Config{Theme: "ocean", BreathingMotion: true}); err != ErrEntitlementNeeded {
		t.Fatalf("paid theme error = %v, want %v", err, ErrEntitlementNeeded)
	}
	starlight := New(repo, entitlementStub{tier: "starlight"})
	updated, err := starlight.UpdateConfig(context.Background(), 1, domain.Config{Theme: "ocean", BreathingMotion: true})
	if err != nil || updated.Theme != "ocean" {
		t.Fatalf("update paid theme = %+v, %v", updated, err)
	}
}

func TestThemeCatalogMarksPaidThemesLocked(t *testing.T) {
	repo := &memoryRepo{config: domain.Config{Theme: domain.ThemeMorningMist}}
	items, err := New(repo, entitlementStub{tier: "glimmer"}).Themes(context.Background(), 1)
	if err != nil {
		t.Fatal(err)
	}
	for _, item := range items {
		if item.RequiredTier == "starlight" && !item.Locked {
			t.Fatalf("paid theme is unlocked: %+v", item)
		}
	}
}
