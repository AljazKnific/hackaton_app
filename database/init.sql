CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'collecting_info'
    CHECK (status IN ('collecting_info', 'text_ready', 'speech_ready', 'expired')),
  extraction_attempts INTEGER NOT NULL DEFAULT 0,
  extracted JSONB NOT NULL DEFAULT '{}',
  marketing_text TEXT,
  tips JSONB,
  duration_preset SMALLINT CHECK (duration_preset IN (15, 30, 60)),
  voice_preset_id UUID,
  audio_path TEXT,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '24 hours'
);

CREATE TABLE prompt_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  version INTEGER NOT NULL,
  system_prompt TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE voice_presets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  voice_id TEXT NOT NULL,
  stability REAL NOT NULL,
  similarity_boost REAL NOT NULL,
  style REAL NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

ALTER TABLE sessions ADD CONSTRAINT sessions_voice_preset_fk
  FOREIGN KEY (voice_preset_id) REFERENCES voice_presets(id);

CREATE INDEX sessions_expiry_idx ON sessions (expires_at);
