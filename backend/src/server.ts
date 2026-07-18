import { createApp, cleanExpiredSessions } from './app.js';
import { createPool, seedConfiguration } from './db.js';
import { loadKnowledgeBase } from './knowledge.js';

const port = Number(process.env.PORT ?? 3000);
const pool = createPool();
await pool.query('SELECT 1');
await seedConfiguration(pool);
await loadKnowledgeBase();
const app = createApp(pool);
const server = app.listen(port, () =>
  console.log(`Marketing API listening on http://localhost:${port}`),
);
setInterval(() => cleanExpiredSessions(pool).catch(console.error), 60 * 60 * 1000).unref();

async function shutdown(signal: string): Promise<void> {
  console.info(`Received ${signal}; shutting down gracefully.`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.once('SIGTERM', () => void shutdown('SIGTERM'));
process.once('SIGINT', () => void shutdown('SIGINT'));
