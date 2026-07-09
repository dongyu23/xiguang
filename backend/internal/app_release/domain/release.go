package domain

import "time"

// Release 表示一次客户端版本发布。
//
// 平台 + 渠道 + build_number 三元组唯一。build_number 是客户端比对的唯一依据，
// version 字段仅用于 UI 展示。一旦发布，version / build_number / apk_file_name /
// sha256 / channel / platform 不可修改，只能下架重发新版本。
type Release struct {
	ID                int64     `json:"id"`
	PublicID          string    `json:"public_id"`
	Channel           string    `json:"channel"`
	Platform          string    `json:"platform"`
	Version           string    `json:"version"`
	BuildNumber       int       `json:"build_number"`
	MinSupportedBuild int       `json:"min_supported_build"`
	APKFileName       string    `json:"apk_file_name"`
	APKSizeBytes      int64     `json:"apk_size_bytes"`
	SHA256            string    `json:"sha256"`
	ReleaseNote       string    `json:"release_note"`
	ForceUpdate       bool      `json:"force_update"`
	PublishedAt       time.Time `json:"published_at"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// PublishParams 描述一次发布所需的全部参数。文件必须先上传到 Nginx 静态目录，
// service 层会校验文件存在性和 SHA-256。
type PublishParams struct {
	Channel           string
	Platform          string
	Version           string
	BuildNumber       int
	MinSupportedBuild int
	APKFileName       string
	APKSizeBytes      int64
	SHA256            string
	ReleaseNote       string
	ForceUpdate       bool
}

// UpdatePolicyParams 描述发布后允许调整的运营策略字段。
// 故意只暴露这三个字段——其他字段一旦发布即不可变。
type UpdatePolicyParams struct {
	ReleaseNote       *string
	ForceUpdate       *bool
	MinSupportedBuild *int
}

// LatestQuery 是查询某 channel + platform 最新版本的入参。
type LatestQuery struct {
	Channel  string
	Platform string
}

// PublicView 是公开接口返回给客户端的视图，去掉了管理员才关心的内部字段。
type PublicView struct {
	LatestVersion     string    `json:"latest_version"`
	LatestBuild       int       `json:"latest_build"`
	MinSupportedBuild int       `json:"min_supported_build"`
	DownloadURL       string    `json:"download_url"`
	APKSizeBytes      int64     `json:"apk_size_bytes"`
	SHA256            string    `json:"sha256"`
	ReleaseNote       string    `json:"release_note"`
	ForceUpdate       bool      `json:"force_update"`
	PublishedAt       time.Time `json:"published_at"`
}

// VersionMeta 是 piggyback 携带在其他响应里的轻量版本提示。
type VersionMeta struct {
	LatestBuild       int `json:"latest_build"`
	MinSupportedBuild int `json:"min_supported_build"`
}
