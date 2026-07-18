import { Pool } from 'pg';

export type Extracted = {
  product_name: string | null;
  target_audience: string | null;
  tone: string | null;
  key_benefit: string | null;
};

export function createPool(connectionString = process.env.DATABASE_URL): Pool {
  if (!connectionString) throw new Error('DATABASE_URL must be set');
  return new Pool({ connectionString });
}

export async function seedConfiguration(pool: Pool): Promise<void> {
  await pool.query(
    `INSERT INTO prompt_templates (name, version, system_prompt)
     SELECT 'marketing-copy', 1, $1
     WHERE NOT EXISTS (SELECT 1 FROM prompt_templates WHERE name = 'marketing-copy' AND version = 1)`,
    ['Create concise, compelling marketing copy from the supplied product facts. Return JSON with marketing_text and tips.'],
  );
  // These are delivery variations of the supplied ElevenLabs voice. Configure
  // separate voice IDs later if the presets should use distinct speakers.
  const voiceId = process.env.ELEVENLABS_VOICE_ID ?? 'JBFqnCBsd6RMkjVDRZzb';
  const presets = [
    ['Calm & reassuring', 0.72, 0.72, 0.1],
    ['Energetic & upbeat', 0.32, 0.8, 0.7],
    ['Professional & confident', 0.52, 0.78, 0.3],
    ['Casual & conversational', 0.45, 0.7, 0.5],
  ] as const;
  for (const [label, stability, similarityBoost, style] of presets) {
    await pool.query(
      `INSERT INTO voice_presets (label, voice_id, stability, similarity_boost, style)
       SELECT $1, $2, $3, $4, $5
       WHERE NOT EXISTS (SELECT 1 FROM voice_presets WHERE label = $1)`,
      [label, voiceId, stability, similarityBoost, style],
    );
  }
}
