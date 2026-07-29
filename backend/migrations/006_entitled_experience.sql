CREATE TABLE IF NOT EXISTS user_space_configs (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme VARCHAR(64) NOT NULL DEFAULT 'morning_mist',
  breathing_motion BOOLEAN NOT NULL DEFAULT TRUE,
  white_noise_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
