import { Hono } from 'hono';
import { handle } from 'hono/vercel';
import { GoogleGenerativeAI } from '@google/generative-ai';

// Initialize Hono app
const app = new Hono().basePath('/api');

// Gemini client (API Key from Vercel Environment Variables)
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');

// --- POST /api/generate ---
app.post('/generate', async (c) => {
  try {
    // 1. Optional: Basic Auth check (shared secret between Flutter and Backend)
    const authHeader = c.req.header('Authorization');
    const expectedSecret = process.env.API_SECRET;
    if (expectedSecret && authHeader !== `Bearer ${expectedSecret}`) {
      return c.json({ error: 'Unauthorized' }, 401);
    }

    // 2. Parse request body
    const body = await c.req.json();
    const tags: string[] = body.tags || [];
    const groupSize: number = body.groupSize || 2;

    if (tags.length === 0) {
      return c.json({ error: 'No tags provided' }, 400);
    }

    // 3. Build prompt (same logic as Flutter client)
    const prompt = `
あなたは「待ち時間を遊びに変える」クリエイティブなゲームデザイナーです。
以下の状況に合わせて、その場で楽しめるシンプルなゲームを1つ提案してください。

**状況:**
- 人数: ${groupSize}人
- 状況タグ: ${tags.join(', ')}

**出力形式 (厳守):**
ゲーム名: [短く覚えやすい名前]
---
遊び方:
[3-5行で簡潔にルールを説明。特別な道具は使わない。]
---
ポイント:
[このゲームが楽しい理由を1行で]
`;

    // 4. Call Gemini API
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // 5. Return generated game
    return c.json({ game: text });

  } catch (error: any) {
    console.error('Gemini API Error:', error);
    return c.json({ error: 'Failed to generate game', details: error.message }, 500);
  }
});

// Default export for Vercel
export default handle(app);
