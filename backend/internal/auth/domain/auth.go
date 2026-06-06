package domain

import "time"

type User struct {
	ID           int64     `json:"id"`
	PublicID     string    `json:"public_id"`
	Username     string    `json:"username"`
	Nickname     string    `json:"nickname"`
	AvatarKey    string    `json:"avatar_key"`
	AIEnabled    bool      `json:"ai_enabled"`
	PrivacyMode  string    `json:"privacy_mode"`
	CreatedAt    time.Time `json:"created_at"`
	PasswordHash string    `json:"-"`
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type RegisterParams struct {
	Username string
	Password string
	Nickname string
}

type LoginParams struct {
	Username string
	Password string
}

type UpdateUserParams struct {
	Nickname    string
	AvatarKey   string
	AIEnabled   *bool
	PrivacyMode string
}
