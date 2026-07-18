import cors from 'cors';
import express from 'express';
import { randomBytes } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { createSpeech, extractFacts, generateCopy, moderate, removeAudio } from './services.js';
const requiredFields = ['product_name', 'target_audience', 'tone', 'key_benefit'];
const creationHits = new Map();
function bearer(request) {
    const value = request.header('authorization');
    return value?.startsWith('Bearer ') ? value.slice(7) : null;
}
function validDuration(value) { return value === 15 || value === 30 || value === 60; }
function missing(extracted) { return requiredFields.filter((key) => !extracted[key]?.trim()); }
async function locked(pool, id, fn) {
    const client = await pool.connect();
    try {
        const result = await client.query('SELECT pg_try_advisory_lock(hashtext($1)) AS locked', [id]);
        if (!result.rows[0]?.locked)
            return null;
        try {
            return await fn(client);
        }
        finally {
            await client.query('SELECT pg_advisory_unlock(hashtext($1))', [id]);
        }
    }
    finally {
        client.release();
    }
}
async function authorised(pool, id, token) {
    if (!token)
        return null;
    const result = await pool.query(`SELECT * FROM sessions WHERE id = $1 AND token = $2
    AND expires_at > now() AND status <> 'expired'`, [id, token]);
    return result.rows[0] ?? null;
}
export function createApp(pool) {
    const app = express();
    app.use(cors());
    app.use(express.json({ limit: '20kb' }));
    app.get('/health', (_req, res) => res.json({ status: 'ok' }));
    app.post('/sessions', async (req, res, next) => {
        const ip = req.ip ?? 'unknown';
        const now = Date.now();
        const hits = (creationHits.get(ip) ?? []).filter((time) => now - time < 3_600_000);
        if (hits.length >= 10)
            return res.status(429).json({ error: 'too many sessions; try again later' });
        if (!validDuration(req.body?.duration_preset))
            return res.status(400).json({ error: 'duration_preset must be 15, 30, or 60' });
        hits.push(now);
        creationHits.set(ip, hits);
        try {
            const token = randomBytes(32).toString('base64url');
            const result = await pool.query('INSERT INTO sessions (token, duration_preset) VALUES ($1, $2) RETURNING id', [token, req.body.duration_preset]);
            return res.status(201).json({ session_id: result.rows[0].id, token });
        }
        catch (error) {
            return next(error);
        }
    });
    app.post('/sessions/:id/messages', async (req, res, next) => {
        if (typeof req.body?.text !== 'string' || !req.body.text.trim())
            return res.status(400).json({ error: 'text is required' });
        try {
            const session = await authorised(pool, req.params.id, bearer(req));
            if (!session)
                return res.status(401).json({ error: 'invalid or expired session token' });
            if (session.extraction_attempts >= 5)
                return res.status(429).json({ complete: false, missing_fields: missing(session.extracted), requires_manual_entry: true });
            const result = await locked(pool, session.id, async (client) => {
                const current = await authorised(pool, session.id, bearer(req));
                if (!current)
                    throw new Error('session expired');
                const output = await extractFacts(req.body.text, current.extracted);
                const absent = missing(output.extracted);
                const complete = absent.length === 0;
                await client.query(`UPDATE sessions SET extraction_attempts = extraction_attempts + 1, extracted = $2,
          updated_at = now() WHERE id = $1`, [session.id, output.extracted]);
                return { complete, missing_fields: absent, extracted: output.extracted };
            });
            if (!result)
                return res.status(409).json({ error: 'another request is already processing this session' });
            return res.json(result);
        }
        catch (error) {
            return next(error);
        }
    });
    app.post('/sessions/:id/details', async (req, res, next) => {
        try {
            const session = await authorised(pool, req.params.id, bearer(req));
            if (!session)
                return res.status(401).json({ error: 'invalid or expired session token' });
            const extracted = { ...session.extracted };
            for (const field of requiredFields)
                if (typeof req.body?.[field] === 'string' && req.body[field].trim())
                    extracted[field] = req.body[field].trim();
            const absent = missing(extracted);
            await pool.query('UPDATE sessions SET extracted = $2, updated_at = now() WHERE id = $1', [session.id, extracted]);
            return res.json({ complete: absent.length === 0, missing_fields: absent, extracted });
        }
        catch (error) {
            return next(error);
        }
    });
    app.post('/sessions/:id/generate-text', async (req, res, next) => {
        try {
            const session = await authorised(pool, req.params.id, bearer(req));
            if (!session)
                return res.status(401).json({ error: 'invalid or expired session token' });
            if (session.status !== 'collecting_info' || missing(session.extracted).length || !session.duration_preset)
                return res.status(409).json({ error: 'complete the product details first' });
            const result = await locked(pool, session.id, async (client) => {
                if (await moderate(session.extracted))
                    throw new Error('The supplied product details cannot be used for marketing copy.');
                const template = await client.query('SELECT system_prompt FROM prompt_templates WHERE is_active = true ORDER BY version DESC LIMIT 1');
                if (!template.rows[0])
                    throw new Error('no active marketing template');
                const copy = await generateCopy(session.extracted, session.duration_preset, template.rows[0].system_prompt);
                await client.query(`UPDATE sessions SET marketing_text = $2, tips = $3, status = 'text_ready', updated_at = now() WHERE id = $1`, [session.id, copy.marketing_text, JSON.stringify(copy.tips)]);
                return copy;
            });
            if (!result)
                return res.status(409).json({ error: 'another request is already processing this session' });
            return res.json(result);
        }
        catch (error) {
            return next(error);
        }
    });
    app.get('/voice-presets', async (_req, res, next) => {
        try {
            const result = await pool.query('SELECT id, label FROM voice_presets WHERE is_active = true ORDER BY label');
            return res.json(result.rows);
        }
        catch (error) {
            return next(error);
        }
    });
    app.post('/sessions/:id/generate-speech', async (req, res, next) => {
        try {
            const session = await authorised(pool, req.params.id, bearer(req));
            if (!session)
                return res.status(401).json({ error: 'invalid or expired session token' });
            if (session.status !== 'text_ready' || !session.marketing_text)
                return res.status(409).json({ error: 'generate marketing text first' });
            if (!validDuration(req.body?.duration_preset) || req.body.duration_preset !== session.duration_preset || typeof req.body?.voice_preset_id !== 'string')
                return res.status(400).json({ error: 'voice_preset_id and the selected duration_preset are required' });
            const result = await locked(pool, session.id, async (client) => {
                const preset = await client.query('SELECT * FROM voice_presets WHERE id = $1 AND is_active = true', [req.body.voice_preset_id]);
                if (!preset.rows[0])
                    throw new Error('voice preset not found');
                const voice = preset.rows[0];
                const audioPath = await createSpeech(session.marketing_text, voice.voice_id, { stability: voice.stability, similarity_boost: voice.similarity_boost, style: voice.style });
                await client.query(`UPDATE sessions SET voice_preset_id = $2, audio_path = $3, status = 'speech_ready', updated_at = now() WHERE id = $1`, [session.id, voice.id, audioPath]);
                return { status: 'done', audio_available: true };
            });
            if (!result)
                return res.status(409).json({ error: 'another request is already processing this session' });
            return res.json(result);
        }
        catch (error) {
            return next(error);
        }
    });
    app.get('/sessions/:id/audio', async (req, res, next) => {
        try {
            const session = await authorised(pool, req.params.id, bearer(req));
            if (!session?.audio_path)
                return res.status(404).json({ error: 'audio not available' });
            res.type('audio/mpeg');
            return createReadStream(session.audio_path).on('error', next).pipe(res);
        }
        catch (error) {
            return next(error);
        }
    });
    app.use((error, _req, res, _next) => { console.error(error); res.status(500).json({ error: error.message === 'The supplied product details cannot be used for marketing copy.' ? error.message : 'internal server error' }); });
    return app;
}
export async function cleanExpiredSessions(pool) {
    const result = await pool.query(`DELETE FROM sessions WHERE expires_at < now() RETURNING audio_path`);
    await Promise.all(result.rows.map((row) => removeAudio(row.audio_path)));
}
