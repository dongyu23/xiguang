-- App 发布版本：管理员发布的客户端构建。
-- 用作客户端轮询拉取最新版本元信息。APK 文件存放在 Nginx 静态目录，仅在表里登记元数据。

DO $$ BEGIN CREATE TYPE release_channel AS ENUM ('stable','beta','canary'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE release_platform AS ENUM ('android','ios'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS app_releases (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  channel release_channel NOT NULL DEFAULT 'stable',
  platform release_platform NOT NULL DEFAULT 'android',
  version VARCHAR(32) NOT NULL,
  build_number INT NOT NULL,
  min_supported_build INT NOT NULL DEFAULT 0,
  apk_file_name VARCHAR(256) NOT NULL,
  apk_size_bytes BIGINT NOT NULL DEFAULT 0,
  sha256 VARCHAR(64) NOT NULL,
  release_note TEXT NOT NULL DEFAULT '',
  force_update BOOLEAN NOT NULL DEFAULT FALSE,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_app_releases_public_id UNIQUE(public_id),
  CONSTRAINT uq_app_releases_channel_platform_build UNIQUE(channel, platform, build_number)
);
CREATE INDEX IF NOT EXISTS idx_app_releases_latest
  ON app_releases(channel, platform, build_number DESC)
  WHERE deleted_at IS NULL;

-- 管理员角色：内部使用。初始化时手动 UPDATE users SET is_admin=TRUE WHERE id=1。
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;
