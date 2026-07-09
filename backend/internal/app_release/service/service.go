package service

import (
	"context"
	"errors"
	"path/filepath"
	"strings"

	"xiguang/backend/internal/app_release/domain"
	"xiguang/backend/internal/app_release/repository"
)

var (
	ErrInvalidParams      = errors.New("release_invalid_params")
	ErrInvalidChannel     = errors.New("release_invalid_channel")
	ErrInvalidPlatform    = errors.New("release_invalid_platform")
	ErrInvalidSHA256      = errors.New("release_invalid_sha256")
	ErrInvalidFileName    = errors.New("release_invalid_file_name")
	ErrBuildNotIncreasing = errors.New("release_build_not_increasing")
	ErrNotFound           = errors.New("release_not_found")
)

const (
	defaultChannel  = "stable"
	defaultPlatform = "android"
	maxListLimit    = 50
)

var (
	allowedChannels  = map[string]bool{"stable": true, "beta": true, "canary": true}
	allowedPlatforms = map[string]bool{"android": true, "ios": true}
)

// Service 维护版本发布、查询、策略调整、下架的业务规则。
//
// 缓存这里没加 Redis——版本接口实际 QPS 很低（每个用户一天最多几次），
// 直接走 PG 简单可靠，避免引入缓存一致性问题。
type Service struct {
	repo          repository.Repository
	downloadBase  string // 例如 "https://host/media/app"
	releaseDirHas func(name string) bool
}

func New(repo repository.Repository, downloadBase string, releaseDirHas func(name string) bool) *Service {
	if downloadBase == "" {
		downloadBase = "/media/app"
	}
	return &Service{repo: repo, downloadBase: strings.TrimRight(downloadBase, "/"), releaseDirHas: releaseDirHas}
}

// Publish 校验后写入一条新发布记录。文件必须先放到 Nginx 静态目录。
func (s *Service) Publish(ctx context.Context, raw domain.PublishParams) (domain.Release, error) {
	p, err := normalizePublishParams(raw)
	if err != nil {
		return domain.Release{}, err
	}
	if s.releaseDirHas != nil && !s.releaseDirHas(p.APKFileName) {
		return domain.Release{}, ErrInvalidFileName
	}
	latest, err := s.repo.FindLatest(ctx, domain.LatestQuery{Channel: p.Channel, Platform: p.Platform})
	if err == nil && p.BuildNumber <= latest.BuildNumber {
		return domain.Release{}, ErrBuildNotIncreasing
	}
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return domain.Release{}, err
	}
	return s.repo.Insert(ctx, p)
}

// LatestPublic 返回某 channel + platform 的最新公开视图。找不到时返回 nil（不是错误）。
func (s *Service) LatestPublic(ctx context.Context, channel, platform string) (*domain.PublicView, error) {
	channel = normalizeChannel(channel)
	platform = normalizePlatform(platform)
	if !allowedChannels[channel] || !allowedPlatforms[platform] {
		return nil, ErrInvalidParams
	}
	rel, err := s.repo.FindLatest(ctx, domain.LatestQuery{Channel: channel, Platform: platform})
	if errors.Is(err, repository.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	view := s.toPublicView(rel)
	return &view, nil
}

// LatestMeta 返回 piggyback 用的轻量版本提示。不存在时返回 nil。
func (s *Service) LatestMeta(ctx context.Context, channel, platform string) *domain.VersionMeta {
	view, err := s.LatestPublic(ctx, channel, platform)
	if err != nil || view == nil {
		return nil
	}
	return &domain.VersionMeta{
		LatestBuild:       view.LatestBuild,
		MinSupportedBuild: view.MinSupportedBuild,
	}
}

func (s *Service) List(ctx context.Context, includeDeleted bool, limit int) ([]domain.Release, error) {
	if limit <= 0 || limit > maxListLimit {
		limit = maxListLimit
	}
	return s.repo.List(ctx, includeDeleted, limit)
}

func (s *Service) GetByPublicID(ctx context.Context, publicID string) (domain.Release, error) {
	rel, err := s.repo.FindByPublicID(ctx, publicID)
	if errors.Is(err, repository.ErrNotFound) {
		return domain.Release{}, ErrNotFound
	}
	return rel, err
}

func (s *Service) UpdatePolicy(ctx context.Context, publicID string, p domain.UpdatePolicyParams) (domain.Release, error) {
	if p.ReleaseNote == nil && p.ForceUpdate == nil && p.MinSupportedBuild == nil {
		return domain.Release{}, ErrInvalidParams
	}
	rel, err := s.repo.UpdatePolicy(ctx, publicID, p)
	if errors.Is(err, repository.ErrNotFound) {
		return domain.Release{}, ErrNotFound
	}
	return rel, err
}

func (s *Service) Retract(ctx context.Context, publicID string) (bool, error) {
	ok, err := s.repo.SoftDelete(ctx, publicID)
	if err != nil {
		return false, err
	}
	if !ok {
		return false, ErrNotFound
	}
	return true, nil
}

func (s *Service) toPublicView(rel domain.Release) domain.PublicView {
	return domain.PublicView{
		LatestVersion:     rel.Version,
		LatestBuild:       rel.BuildNumber,
		MinSupportedBuild: rel.MinSupportedBuild,
		DownloadURL:       s.downloadBase + "/" + rel.APKFileName,
		APKSizeBytes:      rel.APKSizeBytes,
		SHA256:            rel.SHA256,
		ReleaseNote:       rel.ReleaseNote,
		ForceUpdate:       rel.ForceUpdate,
		PublishedAt:       rel.PublishedAt,
	}
}

func normalizePublishParams(p domain.PublishParams) (domain.PublishParams, error) {
	p.Channel = normalizeChannel(p.Channel)
	p.Platform = normalizePlatform(p.Platform)
	p.Version = strings.TrimSpace(p.Version)
	p.APKFileName = strings.TrimSpace(p.APKFileName)
	p.SHA256 = strings.ToLower(strings.TrimSpace(p.SHA256))
	if !allowedChannels[p.Channel] {
		return p, ErrInvalidChannel
	}
	if !allowedPlatforms[p.Platform] {
		return p, ErrInvalidPlatform
	}
	if p.Version == "" || p.BuildNumber <= 0 || p.APKFileName == "" {
		return p, ErrInvalidParams
	}
	if p.MinSupportedBuild < 0 || p.MinSupportedBuild > p.BuildNumber {
		return p, ErrInvalidParams
	}
	if !isHex64(p.SHA256) {
		return p, ErrInvalidSHA256
	}
	// 防止路径穿越——文件名只允许基础形式
	if filepath.Base(p.APKFileName) != p.APKFileName ||
		strings.ContainsAny(p.APKFileName, "/\\") ||
		!strings.HasSuffix(strings.ToLower(p.APKFileName), ".apk") {
		return p, ErrInvalidFileName
	}
	return p, nil
}

func normalizeChannel(value string) string {
	v := strings.ToLower(strings.TrimSpace(value))
	if v == "" {
		return defaultChannel
	}
	return v
}

func normalizePlatform(value string) string {
	v := strings.ToLower(strings.TrimSpace(value))
	if v == "" {
		return defaultPlatform
	}
	return v
}

func isHex64(s string) bool {
	if len(s) != 64 {
		return false
	}
	for _, c := range s {
		switch {
		case c >= '0' && c <= '9':
		case c >= 'a' && c <= 'f':
		default:
			return false
		}
	}
	return true
}
