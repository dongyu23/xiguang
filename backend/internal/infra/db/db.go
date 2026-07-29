package db

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Connect(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	if err := Migrate(ctx, pool); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}

func Migrate(ctx context.Context, pool *pgxpool.Pool) error {
	if _, err := pool.Exec(ctx, schema); err != nil {
		return err
	}
	if _, err := pool.Exec(ctx, billingSchema); err != nil {
		return err
	}
	_, err := pool.Exec(ctx, aiAssistanceSchema)
	return err
}

const schema = `
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN CREATE TYPE fragment_status AS ENUM ('twilight','stardust','echo','seed','tide','island_core'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE media_type AS ENUM ('image','audio'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE island_status AS ENUM ('star_point','growing','formed','dormant','relit'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(256) NOT NULL,
  nickname VARCHAR(128) NOT NULL DEFAULT '',
  avatar_key VARCHAR(512) NOT NULL DEFAULT '',
  ai_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  privacy_mode TEXT NOT NULL DEFAULT 'private',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_users_public_id UNIQUE(public_id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(256) NOT NULL UNIQUE,
  device_info VARCHAR(512),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rt_user ON refresh_tokens(user_id, expires_at DESC) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS fragments (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_text TEXT NOT NULL DEFAULT '',
  emotion VARCHAR(32),
  status fragment_status NOT NULL DEFAULT 'twilight',
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  server_rev BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_fragments_public_id UNIQUE(public_id)
);

CREATE INDEX IF NOT EXISTS idx_fragments_user_created ON fragments(user_id, created_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_fragments_user_emotion ON fragments(user_id, emotion) WHERE is_deleted = FALSE AND emotion IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fragments_user_status ON fragments(user_id, status) WHERE is_deleted = FALSE;

CREATE TABLE IF NOT EXISTS tags (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(128) NOT NULL,
  color VARCHAR(7),
  use_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_tags_public_id UNIQUE(public_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_tags_user_name ON tags(user_id, name) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tags_user ON tags(user_id, created_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS fragment_tags (
  fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(fragment_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_ft_tag ON fragment_tags(tag_id);

CREATE TABLE IF NOT EXISTS relations (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  target_fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  relation_type TEXT NOT NULL,
  custom_label VARCHAR(128),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT ck_relation_no_self CHECK (source_fragment_id <> target_fragment_id),
  CONSTRAINT uq_relation_public_id UNIQUE(public_id),
  UNIQUE(user_id, source_fragment_id, target_fragment_id, relation_type)
);
CREATE INDEX IF NOT EXISTS idx_relation_source ON relations(source_fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_relation_target ON relations(target_fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_relation_user ON relations(user_id, created_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS media_files (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  media_type media_type NOT NULL,
  object_key TEXT NOT NULL,
  file_name VARCHAR(512) NOT NULL,
  file_size BIGINT NOT NULL DEFAULT 0,
  mime_type VARCHAR(128) NOT NULL DEFAULT '',
  width INT,
  height INT,
  duration_ms INT,
  thumbnail_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_media_public_id UNIQUE(public_id)
);
CREATE INDEX IF NOT EXISTS idx_media_fragment ON media_files(fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_media_user ON media_files(user_id, created_at DESC) WHERE deleted_at IS NULL;
ALTER TABLE media_files ALTER COLUMN object_key TYPE TEXT;
ALTER TABLE media_files ALTER COLUMN thumbnail_key TYPE TEXT;
ALTER TABLE media_files ALTER COLUMN file_size SET DEFAULT 0;
ALTER TABLE media_files ALTER COLUMN mime_type SET DEFAULT '';

CREATE TABLE IF NOT EXISTS islands (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(256) NOT NULL,
  description TEXT,
  cover_fragment_id BIGINT REFERENCES fragments(id),
  status island_status NOT NULL DEFAULT 'star_point',
  source_tag_id BIGINT REFERENCES tags(id),
  fragment_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  dormant_at TIMESTAMPTZ,
  relit_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_island_public_id UNIQUE(public_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_island_user_tag ON islands(user_id, source_tag_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_island_user ON islands(user_id, updated_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_island_user_status ON islands(user_id, status) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS island_fragments (
  island_id BIGINT NOT NULL REFERENCES islands(id) ON DELETE CASCADE,
  fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(island_id, fragment_id)
);
CREATE INDEX IF NOT EXISTS idx_if_fragment ON island_fragments(fragment_id);

CREATE TABLE IF NOT EXISTS oplog (
  id BIGSERIAL PRIMARY KEY,
  server_rev BIGSERIAL NOT NULL,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_op_id VARCHAR(64) NOT NULL,
  entity_type TEXT NOT NULL,
  op_type TEXT NOT NULL,
  entity_id BIGINT NOT NULL DEFAULT 0,
  entity_public_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  client_seq BIGINT NOT NULL DEFAULT 0,
  device_id VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, client_op_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_oplog_server_rev ON oplog(server_rev);
CREATE INDEX IF NOT EXISTS idx_oplog_user_rev ON oplog(user_id, server_rev);

CREATE TABLE IF NOT EXISTS ai_requests (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode TEXT NOT NULL,
  fragment_ids BIGINT[] NOT NULL DEFAULT '{}',
  input_prompt TEXT,
  output_raw TEXT,
  keywords TEXT[],
  emotion_title VARCHAR(256),
  summary_text TEXT,
  suggestion_ids BIGINT[],
  token_used INT,
  status TEXT NOT NULL DEFAULT 'not_implemented',
  response JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_ai_user_status ON ai_requests(user_id, status, created_at DESC);

-- App 发布版本：管理员发布的客户端构建。
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
CREATE INDEX IF NOT EXISTS idx_app_releases_latest ON app_releases(channel, platform, build_number DESC) WHERE deleted_at IS NULL;

-- 管理员角色字段：内部使用，初始化时手动 UPDATE users SET is_admin=TRUE WHERE id=1。
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- AI 数据外发同意标记（migration 003）：用户首次开启星图管理员时记录同意时间。
-- NULL = 未同意；非 NULL = 已同意的时间戳。
ALTER TABLE users ADD COLUMN IF NOT EXISTS ai_consent_accepted_at TIMESTAMPTZ;

-- 归档导入（migration 004）：用户从其他账号导入归档数据的记录。
CREATE TABLE IF NOT EXISTS archive_imports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_account_public_id TEXT NOT NULL DEFAULT '',
  manifest JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  report JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours',
  CONSTRAINT ck_archive_import_status CHECK (status IN ('pending','committing','committed','cancelled','failed'))
);
CREATE INDEX IF NOT EXISTS idx_archive_imports_expiry
  ON archive_imports(expires_at) WHERE status IN ('pending','failed');

CREATE TABLE IF NOT EXISTS archive_import_media (
  import_id UUID NOT NULL REFERENCES archive_imports(id) ON DELETE CASCADE,
  sha256 CHAR(64) NOT NULL,
  object_key TEXT NOT NULL,
  mime_type VARCHAR(128) NOT NULL,
  file_size BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(import_id, sha256)
);
`
