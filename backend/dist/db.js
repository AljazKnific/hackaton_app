import { Pool } from 'pg';
export function createPool(connectionString = process.env.DATABASE_URL) {
    if (!connectionString)
        throw new Error('DATABASE_URL must be set');
    return new Pool({ connectionString });
}
export async function seedConfiguration(pool) {
    await pool.query(`INSERT INTO prompt_templates (name, version, system_prompt)
     SELECT 'marketing-copy', 1, $1
     WHERE NOT EXISTS (SELECT 1 FROM prompt_templates WHERE name = 'marketing-copy' AND version = 1)`, ['Create concise, compelling marketing copy from the supplied product facts. Return JSON with marketing_text and tips.']);
    const voiceId = process.env.ELEVENLABS_CALM_VOICE_ID;
    if (voiceId) {
        await pool.query(`INSERT INTO voice_presets (label, voice_id, stability, similarity_boost, style)
       SELECT 'Calm', $1, 0.7, 0.75, 0.15
       WHERE NOT EXISTS (SELECT 1 FROM voice_presets WHERE label = 'Calm')`, [voiceId]);
    }
}
