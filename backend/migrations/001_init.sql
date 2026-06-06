-- 隙光 MVP 初始数据库结构。
-- 与 CLAUDE.md 的 11 张核心表保持同构；运行时也会自动执行同类迁移，便于内部验证。

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

CREATE TABLE IF NOT EXISTS media_files (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fragment_id BIGINT NOT NULL REFERENCES fragments(id) ON DELETE CASCADE,
  media_type media_type NOT NULL,
  object_key VARCHAR(512) NOT NULL,
  file_name VARCHAR(512) NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type VARCHAR(128) NOT NULL,
  width INT,
  height INT,
  duration_ms INT,
  thumbnail_key VARCHAR(512),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_media_public_id UNIQUE(public_id)
);
CREATE INDEX IF NOT EXISTS idx_media_fragment ON media_files(fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_media_user ON media_files(user_id, created_at DESC) WHERE deleted_at IS NULL;

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
