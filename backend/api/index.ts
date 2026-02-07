import { Hono } from 'hono';
import { handle } from 'hono/vercel';
import { cors } from 'hono/cors';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { Redis } from '@upstash/redis';
import { Ratelimit } from '@upstash/ratelimit';

const redis = new Redis({
  url: process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL || process.env.KV_URL || '',
  token: process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_TOKEN || '',
});

// Create a new ratelimiter, that allows 10 requests per 60 seconds
const ratelimit = new Ratelimit({
  redis: redis,
  limiter: Ratelimit.slidingWindow(10, '60 s'),
  analytics: true,
});

// Specific limiter for posting games (stricter: 3 per 60s)
const postRatelimit = new Ratelimit({
  redis: redis,
  limiter: Ratelimit.slidingWindow(3, '60 s'),
  analytics: true,
});

// Use Vercel Edge Runtime
export const config = {
  runtime: 'edge'
};

const app = new Hono().basePath('/api');

// Enable CORS
app.use('*', cors());

// Health check endpoint
app.get('/health', (c) => {
  const hasApiKey = !!process.env.GEMINI_API_KEY;
  return c.json({
    status: 'ok',
    hasApiKey,
    keyPreview: hasApiKey ? process.env.GEMINI_API_KEY?.substring(0, 10) + '...' : 'NOT SET'
  });
});

app.use('/*', cors());

// Helper: Check moderation using Gemini
async function checkModeration(text: string, apiKey: string): Promise<boolean> {
  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `
    Analyze the following text for offensive, inappropriate, or harmful content (violence, hate speech, sexual content).
    Text: "${text}"
    
    Reply with only "SAFE" or "UNSAFE".
    `;

    const result = await model.generateContent(prompt);
    const response = result.response.text().trim();
    return response.toUpperCase().includes('SAFE') && !response.toUpperCase().includes('UNSAFE');
  } catch (e) {
    console.error('Moderation check failed:', e);
    // Fail open (allow) if AI fails, or fail closed? Let's fail safe (allow) but log, to not block legit users during outages.
    // Actually, for safety, let's fail safe (allow) for now as MVP.
    return true;
  }
}

// --- POST /api/generate ---
app.post('/generate', async (c) => {
  // Rate Limit Check
  const ip = c.req.header('x-forwarded-for') || '127.0.0.1';
  const { success } = await ratelimit.limit(ip);
  if (!success) {
    return c.json({ error: 'Rate limit exceeded. Please try again later.' }, 429);
  }

  try {
    const body = await c.req.json();
    const { tags, groupSize } = body;
    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      return c.json({ error: 'Server configuration error' }, 500);
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `
    Create a detailed Japanese party game idea based on these contexts: ${tags?.join(', ')}.
    Group size: ${groupSize || 'any'}.
    
    Format the response exactly like this:
    ゲーム名: [Name]
    遊び方: [Rules in 2-3 sentences]
    `;

    const result = await model.generateContent(prompt);
    const response = result.response;
    const gameText = response.text();

    return c.json({ game: gameText });
  } catch (e) {
    console.error(e);
    return c.json({ error: 'Failed to generate game' }, 500);
  }
});

// --- GET /api/games ---
app.get('/games', async (c) => {
  try {
    // Get latest 20 games (zrange always returns strings/objects)
    // Use reverse range to get newest first (based on score=timestamp)
    const games = await redis.zrange('community_games', 0, 19, { rev: true });

    const parsedGames = games.map((g: any) => {
      if (typeof g === 'string') {
        try { return JSON.parse(g); } catch { return null; }
      }
      return g;
    }).filter((g: any) => g !== null);

    return c.json({ games: parsedGames });
  } catch (e) {
    console.error('Fetch error:', e);
    return c.json({ error: 'Failed to fetch games' }, 500);
  }
});

// --- POST /api/games ---
app.post('/games', async (c) => {
  // Rate Limit Check (Stricter)
  const ip = c.req.header('x-forwarded-for') || '127.0.0.1';
  const { success } = await postRatelimit.limit(`post_${ip}`);
  if (!success) {
    return c.json({ error: 'Posting too fast. Please wait.' }, 429);
  }

  try {
    const gameData = await c.req.json();

    // Basic Validation
    if (!gameData.title || !gameData.rules) {
      return c.json({ error: 'Invalid game data' }, 400);
    }

    // Moderation Check
    const apiKey = process.env.GEMINI_API_KEY;
    if (apiKey) {
      const isSafe = await checkModeration(`${gameData.title}\n${gameData.rules}`, apiKey);
      if (!isSafe) {
        return c.json({ error: 'Content flagged as inappropriate.' }, 400);
      }
    }

    // Add timestamp if missing
    gameData.createdAt = Date.now();

    // Add to sorted set with timestamp score
    await redis.zadd('community_games', { score: Date.now(), member: JSON.stringify(gameData) });

    return c.json({ success: true, game: gameData }, 201);

  } catch (e) {
    console.error('Submit error:', e);
    return c.json({ error: 'Failed to submit game' }, 500);
  }
});

export default handle(app);
