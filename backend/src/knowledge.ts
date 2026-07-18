import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

// The generation prompt is grounded in a knowledge base of `-v2` folders under
// `knowledge/`. Every `.md` file is loaded and concatenated once at startup, so
// dropping a new folder in (e.g. Voice-v2, Emotions-v2) is automatically picked
// up on the next boot — no code change. Legacy `.html` navigators are ignored.

const KB_PATH = process.env.KNOWLEDGE_BASE_PATH ?? path.resolve(process.cwd(), '../knowledge');

let cached = '';

async function collectMarkdown(dir: string, rel: string): Promise<string[]> {
  const entries = await readdir(dir, { withFileTypes: true });
  const out: string[] = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const full = path.join(dir, entry.name);
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      out.push(...(await collectMarkdown(full, relPath)));
    } else if (entry.name.toLowerCase().endsWith('.md')) {
      out.push(`\n\n===== ${relPath} =====\n${await readFile(full, 'utf8')}`);
    }
  }
  return out;
}

// Load and cache the whole knowledge base. Called once from server.ts at startup.
export async function loadKnowledgeBase(): Promise<void> {
  try {
    const parts = await collectMarkdown(KB_PATH, '');
    cached = parts.join('');
    console.info(`[knowledge] loaded ${parts.length} files (${(cached.length / 1024).toFixed(0)}KB) from ${KB_PATH}`);
  } catch (error) {
    cached = '';
    console.warn(`[knowledge] could not load from ${KB_PATH}: ${(error as Error).message}`);
  }
}

export function knowledgeReference(): string {
  return cached;
}
