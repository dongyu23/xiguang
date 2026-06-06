package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"xiguang/backend/internal/auth/domain"
	"xiguang/backend/internal/infra/config"
)

type fakeAuthRepo struct {
	refreshTokens map[string]int64
}

func (f *fakeAuthRepo) CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error) {
	return domain.User{}, nil
}

func (f *fakeAuthRepo) FindByUsername(ctx context.Context, username string) (domain.User, error) {
	return domain.User{}, nil
}

func (f *fakeAuthRepo) FindByID(ctx context.Context, id int64) (domain.User, error) {
	return domain.User{}, nil
}

func (f *fakeAuthRepo) UpdateUser(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error) {
	return domain.User{}, nil
}

func (f *fakeAuthRepo) InsertRefreshToken(ctx context.Context, userID int64, tokenHash string, expiresAt time.Time) error {
	f.refreshTokens[tokenHash] = userID
	return nil
}

func (f *fakeAuthRepo) FindRefreshUserID(ctx context.Context, tokenHash string) (int64, error) {
	userID, ok := f.refreshTokens[tokenHash]
	if !ok {
		return 0, ErrRefreshFailed
	}
	return userID, nil
}

func (f *fakeAuthRepo) RotateRefreshToken(ctx context.Context, oldTokenHash, newTokenHash string, expiresAt time.Time) (int64, error) {
	userID, ok := f.refreshTokens[oldTokenHash]
	if !ok {
		return 0, ErrRefreshFailed
	}
	delete(f.refreshTokens, oldTokenHash)
	f.refreshTokens[newTokenHash] = userID
	return userID, nil
}

func TestRefreshRotatesRefreshToken(t *testing.T) {
	repo := &fakeAuthRepo{refreshTokens: map[string]int64{}}
	svc := New(repo, config.Config{
		JWTSecret:     "test-secret",
		AccessExpiry:  time.Minute,
		RefreshExpiry: time.Hour,
	})

	oldRefresh := "old-refresh"
	repo.refreshTokens[tokenHash(oldRefresh)] = 42
	first, err := svc.Refresh(context.Background(), oldRefresh)
	if err != nil {
		t.Fatalf("first refresh failed: %v", err)
	}
	if first.RefreshToken == "" || first.RefreshToken == oldRefresh {
		t.Fatalf("expected a rotated refresh token, got %q", first.RefreshToken)
	}

	_, err = svc.Refresh(context.Background(), oldRefresh)
	if !errors.Is(err, ErrRefreshFailed) {
		t.Fatalf("old refresh token should be revoked, got %v", err)
	}

	second, err := svc.Refresh(context.Background(), first.RefreshToken)
	if err != nil {
		t.Fatalf("new refresh token should work: %v", err)
	}
	if second.RefreshToken == first.RefreshToken {
		t.Fatal("refresh token should rotate on every refresh")
	}
}
