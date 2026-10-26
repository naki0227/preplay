import { Hono } from 'hono';
import { handle } from 'hono/vercel';
import { cors } from 'hono/cors';

// Simple per-instance rate limit (10 requests / 60 s per IP). It is not
// shared between instances, so the hard cost limit is the spend cap set on
// the Gemini project in AI Studio.
const memoryHits = new Map<string, number[]>();
function memoryLimit(key: string, max: number, windowMs: number): boolean {
  const now = Date.now();
  if (memoryHits.size > 10_000) memoryHits.clear(); // keep memory bounded
  const hits = (memoryHits.get(key) || []).filter((t) => now - t < windowMs);
  if (hits.length >= max) {
    memoryHits.set(key, hits);
    return false;
  }
  hits.push(now);
  memoryHits.set(key, hits);
  return true;
}

function clientIp(header: string | undefined): string {
  return header?.split(',')[0]?.trim() || '127.0.0.1';
}

// The app only ever sends these situation tags (lib/services/situation_service.dart).
// Anything else is rejected so the endpoint cannot be used as a free
// general-purpose prompt proxy: user input never reaches the prompt as text.
const ALLOWED_TAGS = new Set(['all', 'active', 'noisy', 'quiet', 'standing', 'waiting', 'walking']);

export function parseRequest(body: any): { tags: string[]; groupSize: number } | null {
  const { tags, groupSize = 2 } = body ?? {};
  if (!Array.isArray(tags) || tags.length === 0 || tags.length > ALLOWED_TAGS.size) return null;
  if (!tags.every((t) => typeof t === 'string' && ALLOWED_TAGS.has(t))) return null;
  if (!Number.isInteger(groupSize) || groupSize < 1 || groupSize > 20) return null;
  return { tags: [...new Set<string>(tags)], groupSize };
}

// gemini-1.5-flash was retired, which broke generation. Keep the model
// configurable so the next retirement only needs an env change.
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';

async function generateText(prompt: string, apiKey: string): Promise<string> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }] }),
    }
  );
  if (!res.ok) {
    // Log status and body only; never the key.
    throw new Error(`Gemini API error ${res.status}: ${(await res.text()).slice(0, 500)}`);
  }
  const data: any = await res.json();
  const text = (data?.candidates?.[0]?.content?.parts || [])
    .map((p: any) => p?.text || '')
    .join('');
  if (!text) throw new Error('Gemini API returned no text');
  return text;
}

// Daily counters in Supabase (public.bump_stat, see supabase/migrations).
// Only the kind of outcome is stored: no IP, no tags, nothing per person.
// Skipped when SUPABASE_URL / SUPABASE_ANON_KEY are not set, and never fails
// the request.
export type StatKind = 'ai_ok' | 'ai_error' | 'ai_rate_limited' | 'ai_invalid';
async function bumpStat(kind: StatKind, monitor: boolean): Promise<void> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  // The hourly check (tools/monitor) is not a user; keep it out of the numbers.
  if (!url || !key || monitor) return;
  try {
    const res = await fetch(`${url}/rest/v1/rpc/bump_stat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: key },
      body: JSON.stringify({ stat_kind: kind }),
      signal: AbortSignal.timeout(2000),
    });
    if (!res.ok) console.error(`bump_stat ${kind}: ${res.status}`);
  } catch (e) {
    console.error(`bump_stat ${kind} failed`, e);
  }
}

// Use Vercel Edge Runtime
export const config = {
  runtime: 'edge'
};

const app = new Hono().basePath('/api');

// Enable CORS
app.use('*', cors());

// Health check endpoint
app.get('/health', (c) => {
  // Do not expose any part of the key.
  return c.json({
    status: 'ok',
    hasApiKey: !!process.env.GEMINI_API_KEY,
    model: GEMINI_MODEL,
  });
});

app.use('/*', cors());

// --- POST /api/generate ---
app.post('/generate', async (c) => {
  const monitor = c.req.header('x-preplay-monitor') === '1';

  // Rate Limit Check
  const ip = clientIp(c.req.header('x-forwarded-for'));
  if (!memoryLimit(ip, 10, 60_000)) {
    await bumpStat('ai_rate_limited', monitor);
    return c.json({ error: 'Rate limit exceeded. Please try again later.' }, 429);
  }

  try {
    const parsed = parseRequest(await c.req.json().catch(() => null));
    if (!parsed) {
      await bumpStat('ai_invalid', monitor);
      return c.json({ error: 'Invalid request' }, 400);
    }
    const { tags, groupSize } = parsed;
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      await bumpStat('ai_error', monitor);
      return c.json({ error: 'Server configuration error' }, 500);
    }

    const prompt = `
    Create a detailed Japanese party game idea based on these contexts: ${tags.join(', ')}.
    Group size: ${groupSize}.
    
    Format the response exactly like this, in plain text without Markdown:
    ゲーム名: [Name]
    遊び方: [Rules in 2-3 sentences]
    `;

    // The app parses "ゲーム名:" / "遊び方:" lines, so strip Markdown that
    // newer models tend to add (e.g. "**ゲーム名:**").
    const gameText = (await generateText(prompt, apiKey)).replace(/[*#`]/g, '').trim();

    await bumpStat('ai_ok', monitor);
    return c.json({ game: gameText });
  } catch (e) {
    console.error(e);
    await bumpStat('ai_error', monitor);
    return c.json({ error: 'Failed to generate game' }, 500);
  }
});

export default handle(app);
