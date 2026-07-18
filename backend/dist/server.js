import { createApp, cleanExpiredSessions } from './app.js';
import { createPool, seedConfiguration } from './db.js';
const port = Number(process.env.PORT ?? 3000);
const pool = createPool();
await pool.query('SELECT 1');
await seedConfiguration(pool);
const app = createApp(pool);
app.listen(port, () => console.log(`Marketing API listening on http://localhost:${port}`));
setInterval(() => cleanExpiredSessions(pool).catch(console.error), 60 * 60 * 1000).unref();
