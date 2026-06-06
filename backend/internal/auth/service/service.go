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
	ErrInvalidAccount = errors.New("invalid_account")
	ErrLoginFailed    = errors.New("login_failed")
	ErrRefreshFailed  = errors.New("refresh_failed")
)

type Service struct {
	repo repository.Repository
	cfg  config.Config
}

func New(repo repository.Repository, cfg config.Config) *Service {
	return &Service{repo: repo, cfg: cfg}
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
	tokens, err := s.IssueTokens(ctx, user.ID)
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
	user.PasswordHash = ""
	tokens, err := s.IssueTokens(ctx, user.ID)
	return user, tokens, err
}

func (s *Service) Me(ctx context.Context, id int64) (domain.User, error) {
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

func (s *Service) Refresh(ctx context.Context, refreshToken string) (domain.TokenPair, error) {
	if refreshToken == "" {
		return domain.TokenPair{}, ErrRefreshFailed
	}
	userID, err := s.repo.FindRefreshUserID(ctx, tokenHash(refreshToken))
	if err != nil {
		return domain.TokenPair{}, ErrRefreshFailed
	}
	return s.IssueTokens(ctx, userID)
}

func (s *Service) IssueTokens(ctx context.Context, userID int64) (domain.TokenPair, error) {
	expiresAt := time.Now().Add(s.cfg.AccessExpiry)
	access, err := s.signToken(userID, expiresAt)
	if err != nil {
		return domain.TokenPair{}, err
	}
	refresh, err := randomToken()
	if err != nil {
		return domain.TokenPair{}, err
	}
	err = s.repo.InsertRefreshToken(ctx, userID, tokenHash(refresh), time.Now().Add(s.cfg.RefreshExpiry))
	return domain.TokenPair{AccessToken: access, RefreshToken: refresh, ExpiresAt: expiresAt}, err
}

func (s *Service) ParseToken(token string) (int64, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return 0, shared.ErrUnauthorized
	}
	unsigned := parts[0] + "." + parts[1]
	mac := hmac.New(sha256.New, []byte(s.cfg.JWTSecret))
	mac.Write([]byte(unsigned))
	expected := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(expected), []byte(parts[2])) {
		return 0, shared.ErrUnauthorized
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return 0, err
	}
	var payload struct {
		Sub string `json:"sub"`
		Exp int64  `json:"exp"`
	}
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return 0, err
	}
	if time.Now().Unix() > payload.Exp {
		return 0, shared.ErrUnauthorized
	}
	return strconv.ParseInt(payload.Sub, 10, 64)
}

func (s *Service) signToken(userID int64, expiresAt time.Time) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payloadBytes, err := json.Marshal(map[string]any{"sub": strconv.FormatInt(userID, 10), "exp": expiresAt.Unix()})
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
