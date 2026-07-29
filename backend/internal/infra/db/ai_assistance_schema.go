package db

const aiAssistanceSchema = `
CREATE TABLE IF NOT EXISTS ai_artifacts (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  artifact_type TEXT NOT NULL DEFAULT 'summary',
  scope_type TEXT NOT NULL,
  fragment_ids BIGINT[] NOT NULL DEFAULT '{}',
  island_id BIGINT REFERENCES islands(id) ON DELETE SET NULL,
  range_start TIMESTAMPTZ,
  range_end TIMESTAMPTZ,
  title VARCHAR(256) NOT NULL,
  summary_text TEXT NOT NULL,
  key_points JSONB NOT NULL DEFAULT '[]'::jsonb,
  source_request_id BIGINT REFERENCES ai_requests(id) ON DELETE SET NULL,
  user_edited BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_ai_artifacts_public_id UNIQUE(public_id),
  CONSTRAINT ck_ai_artifact_scope CHECK (scope_type IN ('fragments','island','range'))
);
CREATE INDEX IF NOT EXISTS idx_ai_artifacts_user ON ai_artifacts(user_id, updated_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS island_groups (
  id BIGSERIAL PRIMARY KEY,
  public_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(256) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT 'manual',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT uq_island_groups_public_id UNIQUE(public_id),
  CONSTRAINT ck_island_group_source CHECK (source IN ('manual','ai'))
);
CREATE INDEX IF NOT EXISTS idx_island_groups_user ON island_groups(user_id, updated_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS island_group_members (
  group_id BIGINT NOT NULL REFERENCES island_groups(id) ON DELETE CASCADE,
  island_id BIGINT NOT NULL REFERENCES islands(id) ON DELETE CASCADE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(group_id, island_id)
);
CREATE INDEX IF NOT EXISTS idx_island_group_members_island ON island_group_members(island_id);

ALTER TABLE ai_requests ADD COLUMN IF NOT EXISTS request_type TEXT;
ALTER TABLE ai_requests ADD COLUMN IF NOT EXISTS model TEXT;
ALTER TABLE ai_requests ADD COLUMN IF NOT EXISTS latency_ms INT;
ALTER TABLE ai_requests ADD COLUMN IF NOT EXISTS content_count INT NOT NULL DEFAULT 0;
ALTER TABLE ai_requests ADD COLUMN IF NOT EXISTS error_code TEXT;
UPDATE ai_requests SET input_prompt=NULL, output_raw=NULL, response='{}'::jsonb,
  summary_text=NULL, emotion_title=NULL, keywords=NULL, suggestion_ids=NULL, error_message=NULL
WHERE input_prompt IS NOT NULL OR output_raw IS NOT NULL OR response <> '{}'::jsonb;
`
