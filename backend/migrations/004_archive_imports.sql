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
