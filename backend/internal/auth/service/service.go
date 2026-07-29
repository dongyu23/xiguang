package service

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"xiguang/backend/internal/auth/domain"
	"xiguang/backend/internal/auth/repository"
	"xiguang/backend/internal/infra/config"
	"xiguang/backend/internal/shared"
)

var (
	ErrInvalidAccount           = errors.New("invalid_account")
	ErrLoginFailed              = errors.New("login_failed")
	ErrRefreshFailed            = errors.New("refresh_failed")
	ErrWrongPassword            = errors.New("wrong_password")
	ErrPasswordTooShort         = errors.New("password_too_short")
	ErrObjectCleanupUnavailable = errors.New("object_cleanup_unavailable")
)

type Service struct {
	repo    repository.Repository
	cfg     config.Config
	objects ObjectDeleter
}

type ObjectDeleter interface {
	DeleteObject(context.Context, string) error
}
type mediaObjectLister interface {
	MediaObjectKeys(context.Context, int64) ([]string, error)
}

func New(repo repository.Repository, cfg config.Config, deleters ...ObjectDeleter) *Service {
	var objects ObjectDeleter
	if len(deleters) > 0 {
		objects = deleters[0]
	}
	return &Service{repo: repo, cfg: cfg, objects: objects}
}

func (s *Service) Register(ctx context.Context, params domain.RegisterParams) (domain.User, domain.TokenPair, error) {
	params.Username = strings.TrimSpace(params.Username)
	params.Nickname = strings.TrimSpace(params.Nickname)
	if params.Username == "" || len(params.Password) < 6 {
		return domain.User{}, domain.TokenPair{}, ErrInvalidAccount
	}
	if params.Nickname == "" {
		params.Nickname = params.Username
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(params.Password), bcrypt.DefaultCost)
	if err != nil {
		return domain.User{}, domain.TokenPair{}, err
	}
	user, err := s.repo.CreateUser(ctx, params.Username, string(hash), params.Nickname)
	if err != nil {
		return domain.User{}, domain.TokenPair{}, err
	}
	tokens, err := s.IssueTokens(ctx, user.ID, params.DeviceInfo)
	return user, tokens, err
}

func (s *Service) Login(ctx context.Context, params domain.LoginParams) (domain.User, domain.TokenPair, error) {
	user, err := s.repo.FindByUsername(ctx, strings.TrimSpace(params.Username))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, domain.TokenPair{}, ErrLoginFailed
	}
	if err != nil {
		return domain.User{}, domain.TokenPair{}, err
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(params.Password)) != nil {
		return domain.User{}, domain.TokenPair{}, ErrLoginFailed
	}
	if err := s.repo.EnsureDefaultIsland(ctx, user.ID); err != nil {
		return domain.User{}, domain.TokenPair{}, err
	}
	user.PasswordHash = ""
	tokens, err := s.IssueTokens(ctx, user.ID, params.DeviceInfo)
	return user, tokens, err
}

func (s *Service) Me(ctx context.Context, id int64) (domain.User, error) {
	if err := s.repo.EnsureDefaultIsland(ctx, id); err != nil {
		return domain.User{}, err
	}
	return s.repo.FindByID(ctx, id)
}

func (s *Service) UpdateMe(ctx context.Context, id int64, params domain.UpdateUserParams) (domain.User, error) {
	params.Nickname = strings.TrimSpace(params.Nickname)
	params.PrivacyMode = strings.TrimSpace(params.PrivacyMode)
	if params.PrivacyMode == "" {
		params.PrivacyMode = "private"
	}
	return s.repo.UpdateUser(ctx, id, params)
}

func (s *Service) ChangePassword(ctx context.Context, userID int64, oldPassword, newPassword string) error {
	if len(newPassword) < 6 {
		return ErrPasswordTooShort
	}
	user, err := s.repo.FindByID(ctx, userID)
	if err != nil {
		return err
	}
	// FindByID 不返回 password_hash，需要重新查
	fullUser, err := s.repo.FindByUsername(ctx, user.Username)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(fullUser.PasswordHash), []byte(oldPassword)) != nil {
		return ErrWrongPassword
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return s.repo.UpdatePassword(ctx, userID, string(hash))
}

func (s *Service) DeleteAccount(ctx context.Context, userID int64, password string) error {
	user, err := s.repo.FindByID(ctx, userID)
	if err != nil {
		return err
	}
	fullUser, err := s.repo.FindByUsername(ctx, user.Username)
	if err != nil {
		return err
	}
	if bcrypt.CompareHashAndPassword([]byte(fullUser.PasswordHash), []byte(password)) != nil {
		return ErrWrongPassword
	}
	if lister, ok := s.repo.(mediaObjectLister); ok {
		keys, listErr := lister.MediaObjectKeys(ctx, userID)
		if listErr != nil {
			return listErr
		}
		if len(keys) > 0 && s.objects == nil {
			return ErrObjectCleanupUnavailable
		}
		for _, key := range keys {
			if err := s.objects.DeleteObject(ctx, key); err != nil {
				return err
			}
		}
	}
	return s.repo.DeleteUser(ctx, userID)
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (domain.TokenPair, error) {
	if refreshToken == "" {
		return domain.TokenPair{}, ErrRefreshFailed
	}
	newRefresh, err := randomToken()
	if err != nil {
		return domain.TokenPair{}, err
	}
	accessExpiresAt := time.Now().Add(s.cfg.AccessExpiry)
	userID, tokenID, err := s.repo.RotateRefreshToken(ctx, tokenHash(refreshToken), tokenHash(newRefresh), time.Now().Add(s.cfg.RefreshExpiry))
	if err != nil {
		return domain.TokenPair{}, ErrRefreshFailed
	}
	access, err := s.signToken(userID, tokenID, accessExpiresAt)
	if err != nil {
		return domain.TokenPair{}, err
	}
	return domain.TokenPair{AccessToken: access, RefreshToken: newRefresh, ExpiresAt: accessExpiresAt}, nil
}

func (s *Service) IssueTokens(ctx context.Context, userID int64, deviceInfo string) (domain.TokenPair, error) {
	expiresAt := time.Now().Add(s.cfg.AccessExpiry)
	refresh, err := randomToken()
	if err != nil {
		return domain.TokenPair{}, err
	}
	tokenID, err := s.repo.InsertRefreshToken(ctx, userID, tokenHash(refresh), deviceInfo, time.Now().Add(s.cfg.RefreshExpiry))
	if err != nil {
		return domain.TokenPair{}, err
	}
	access, err := s.signToken(userID, tokenID, expiresAt)
	return domain.TokenPair{AccessToken: access, RefreshToken: refresh, ExpiresAt: expiresAt}, err
}

func (s *Service) ListDevices(ctx context.Context, userID int64) ([]domain.DeviceSession, error) {
	return s.repo.ListDevices(ctx, userID)
}

func (s *Service) RevokeDevice(ctx context.Context, userID, tokenID int64) (bool, error) {
	return s.repo.RevokeDevice(ctx, userID, tokenID)
}

func (s *Service) ParseToken(token string) (int64, error) {
	userID, _, err := s.ParseTokenSession(token)
	return userID, err
}

func (s *Service) ParseTokenSession(token string) (int64, int64, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return 0, 0, shared.ErrUnauthorized
	}
	unsigned := parts[0] + "." + parts[1]
	mac := hmac.New(sha256.New, []byte(s.cfg.JWTSecret))
	mac.Write([]byte(unsigned))
	expected := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(expected), []byte(parts[2])) {
		return 0, 0, shared.ErrUnauthorized
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return 0, 0, err
	}
	var payload struct {
		Sub string `json:"sub"`
		Exp int64  `json:"exp"`
		Sid int64  `json:"sid"`
	}
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return 0, 0, err
	}
	if time.Now().Unix() > payload.Exp {
		return 0, 0, shared.ErrUnauthorized
	}
	userID, err := strconv.ParseInt(payload.Sub, 10, 64)
	if err != nil {
		return 0, 0, err
	}
	if _, err := s.repo.FindByID(context.Background(), userID); err != nil {
		return 0, 0, shared.ErrUnauthorized
	}
	if payload.Sid > 0 {
		active, err := s.repo.DeviceSessionActive(context.Background(), userID, payload.Sid)
		if err != nil || !active {
			return 0, 0, shared.ErrUnauthorized
		}
	}
	return userID, payload.Sid, nil
}

func (s *Service) signToken(userID, tokenID int64, expiresAt time.Time) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payloadBytes, err := json.Marshal(map[string]any{"sub": strconv.FormatInt(userID, 10), "sid": tokenID, "exp": expiresAt.Unix()})
	if err != nil {
		return "", err
	}
	payload := base64.RawURLEncoding.EncodeToString(payloadBytes)
	unsigned := header + "." + payload
	mac := hmac.New(sha256.New, []byte(s.cfg.JWTSecret))
	mac.Write([]byte(unsigned))
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil)), nil
}

func randomToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}
