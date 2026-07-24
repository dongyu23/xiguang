-- AI 数据外发同意标记：用户首次开启星图管理员时记录同意时间，后续开启不再重复弹窗。
-- NULL = 未同意；非 NULL = 已同意的时间戳。关闭 AI 只置 ai_enabled=FALSE，不清空此字段。
ALTER TABLE users ADD COLUMN IF NOT EXISTS ai_consent_accepted_at TIMESTAMPTZ;
