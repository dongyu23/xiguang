package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"

	"xiguang/backend/internal/auth/domain"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/shared"
)

type fakeAuthRepo struct {
	refreshTokens map[string]int64
	lastUpdate    domain.UpdateUserParams
	revokedIDs    map[int64]bool
	user          domain.User
	mediaKeys     []string
	mediaListErr  error
	deletedUserID int64
}

func (f *fakeAuthRepo) CreateUser(ctx context.Context, username, passwordHash, nickname string) (domain.User, error) {
	return domain.User{}, nil
}

func (f *fakeAuthRepo) EnsureDefaultIsland(ctx context.Context, userID int64) error {
	return nil
}

func (f *fakeAuthRepo) FindByUsername(ctx context.Context, username string) (domain.User, error) {
	return f.user, nil
}

func (f *fakeAuthRepo) FindByID(ctx context.Context, id int64) (domain.User, error) {
	return f.user, nil
}

func (f *fakeAuthRepo) UpdateUser(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error) {
	f.lastUpdate = params
	user := domain.User{ID: id, PrivacyMode: params.PrivacyMode}
	if params.AIEnabled != nil {
		user.AIEnabled = *params.AIEnabled
	}
	return user, nil
}

func (f *fakeAuthRepo) UpdatePassword(ctx context.Context, userID int64, passwordHash string) error {
	return nil
}

func (f *fakeAuthRepo) DeleteUser(ctx context.Context, userID int64) error {
	f.deletedUserID = userID
	return nil
}

func (f *fakeAuthRepo) MediaObjectKeys(context.Context, int64) ([]string, error) {
	return f.mediaKeys, f.mediaListErr
}

func (f *fakeAuthRepo) InsertRefreshToken(ctx context.Context, userID int64, tokenHash, deviceInfo string, expiresAt time.Time) (int64, error) {
	f.refreshTokens[tokenHash] = userID
	return int64(len(f.refreshTokens)), nil
}

func (f *fakeAuthRepo) ListDevices(ctx context.Context, userID int64) ([]domain.DeviceSession, error) {
	return nil, nil
}

func (f *fakeAuthRepo) RevokeDevice(ctx context.Context, userID, tokenID int64) (bool, error) {
	return false, nil
}

func (f *fakeAuthRepo) FindRefreshUserID(ctx context.Context, tokenHash string) (int64, error) {
	userID, ok := f.refreshTokens[tokenHash]
	if !ok {
		return 0, ErrRefreshFailed
	}
	return userID, nil
}

func (f *fakeAuthRepo) RotateRefreshToken(ctx context.Context, oldTokenHash, newTokenHash string, expiresAt time.Time) (int64, int64, error) {
	userID, ok := f.refreshTokens[oldTokenHash]
	if !ok {
		return 0, 0, ErrRefreshFailed
	}
	delete(f.refreshTokens, oldTokenHash)
	f.refreshTokens[newTokenHash] = userID
	return userID, int64(len(f.refreshTokens)), nil
}

func (f *fakeAuthRepo) DeviceSessionActive(ctx context.Context, userID, tokenID int64) (bool, error) {
	return !f.revokedIDs[tokenID], nil
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

func TestUpdateMeKeepsAIEnabledOptional(t *testing.T) {
	repo := &fakeAuthRepo{refreshTokens: map[string]int64{}}
	svc := New(repo, config.Config{})

	if _, err := svc.UpdateMe(context.Background(), 7, domain.UpdateUserParams{}); err != nil {
		t.Fatalf("update without ai_enabled failed: %v", err)
	}
	if repo.lastUpdate.AIEnabled != nil {
		t.Fatal("missing ai_enabled should remain nil so repository can preserve the stored value")
	}

	disabled := false
	if _, err := svc.UpdateMe(context.Background(), 7, domain.UpdateUserParams{AIEnabled: &disabled}); err != nil {
		t.Fatalf("update with ai_enabled=false failed: %v", err)
	}
	if repo.lastUpdate.AIEnabled == nil || *repo.lastUpdate.AIEnabled {
		t.Fatal("explicit ai_enabled=false should be preserved")
	}
}

func TestRevokedDeviceInvalidatesItsAccessToken(t *testing.T) {
	repo := &fakeAuthRepo{
		refreshTokens: map[string]int64{},
		revokedIDs:    map[int64]bool{},
	}
	svc := New(repo, config.Config{
		JWTSecret:     "test-secret",
		AccessExpiry:  time.Hour,
		RefreshExpiry: time.Hour,
	})
	tokens, err := svc.IssueTokens(context.Background(), 42, "device-1|Mac")
	if err != nil {
		t.Fatalf("issue tokens: %v", err)
	}
	if _, err := svc.ParseToken(tokens.AccessToken); err != nil {
		t.Fatalf("fresh device token should be active: %v", err)
	}
	userID, sessionID, err := svc.ParseTokenSession(tokens.AccessToken)
	if err != nil {
		t.Fatalf("parse token session: %v", err)
	}
	if userID != 42 || sessionID != 1 {
		t.Fatalf("token session = (%d, %d), want (42, 1)", userID, sessionID)
	}
	repo.revokedIDs[1] = true
	if _, err := svc.ParseToken(tokens.AccessToken); !errors.Is(err, shared.ErrUnauthorized) {
		t.Fatalf("revoked device token should be rejected: %v", err)
	}
}

func TestDeleteAccountRequiresCurrentPassword(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("current-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	repo := &fakeAuthRepo{
		refreshTokens: map[string]int64{},
		user: domain.User{
			ID:           42,
			Username:     "user",
			PasswordHash: string(hash),
		},
	}
	svc := New(repo, config.Config{})

	if err := svc.DeleteAccount(context.Background(), 42, "wrong-password"); !errors.Is(err, ErrWrongPassword) {
		t.Fatalf("wrong password should be rejected: %v", err)
	}
	if repo.deletedUserID != 0 {
		t.Fatal("wrong password must not delete the user")
	}
	if err := svc.DeleteAccount(context.Background(), 42, "current-password"); err != nil {
		t.Fatalf("delete with current password: %v", err)
	}
	if repo.deletedUserID != 42 {
		t.Fatalf("deleted user id = %d, want 42", repo.deletedUserID)
	}
}

type fakeObjectDeleter struct {
	deleted []string
	err     error
}

func (d *fakeObjectDeleter) DeleteObject(_ context.Context, key string) error {
	if d.err != nil {
		return d.err
	}
	d.deleted = append(d.deleted, key)
	return nil
}

func TestDeleteAccountCleansMediaObjectsBeforeDeletingUser(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("current-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	repo := &fakeAuthRepo{
		refreshTokens: map[string]int64{},
		user:          domain.User{ID: 42, Username: "user", PasswordHash: string(hash)},
		mediaKeys:     []string{"users/42/a.jpg", "users/42/b.m4a"},
	}
	objects := &fakeObjectDeleter{}
	service := New(repo, config.Config{}, objects)

	if err = service.DeleteAccount(t.Context(), 42, "current-password"); err != nil {
		t.Fatal(err)
	}
	if len(objects.deleted) != 2 || repo.deletedUserID != 42 {
		t.Fatalf("deleted objects=%#v user=%d", objects.deleted, repo.deletedUserID)
	}
}

func TestDeleteAccountFailsClosedWhenObjectCleanupIsUnavailable(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("current-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	repo := &fakeAuthRepo{
		refreshTokens: map[string]int64{},
		user:          domain.User{ID: 42, Username: "user", PasswordHash: string(hash)},
		mediaKeys:     []string{"users/42/a.jpg"},
	}
	service := New(repo, config.Config{})

	if err = service.DeleteAccount(t.Context(), 42, "current-password"); !errors.Is(err, ErrObjectCleanupUnavailable) {
		t.Fatalf("DeleteAccount() error = %v", err)
	}
	if repo.deletedUserID != 0 {
		t.Fatal("user was deleted while media cleanup was unavailable")
	}
}
