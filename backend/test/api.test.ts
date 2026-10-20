// Run with: npm test
// Reproduces the production failure: Upstash Redis unreachable (archived DB)
// must not break /api/generate, and the Gemini key must never leak.
import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.GEMINI_API_KEY = 'test-key-not-real-0123456789';
process.env.KV_REST_API_URL = 'https://redis.invalid';
process.env.KV_REST_API_TOKEN = 'x';

const realFetch = globalThis.fetch;
let geminiCalls: string[] = [];
globalThis.fetch = (async (input: any, init?: any) => {
  const url = typeof input === 'string' ? input : input.url;
  if (url.startsWith('https://generativelanguage.googleapis.com/')) {
    geminiCalls.push(url);
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: '**ゲーム名:** テスト\n**遊び方:** ルール' }] } }],
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
  if (url.startsWith('https://redis.invalid')) {
    return new Response('internal error', { status: 500 });
  }
  return realFetch(input, init);
}) as typeof fetch;

const { default: handler } = await import('../api/index.ts');

const call = (path: string, init?: RequestInit) =>
  (handler as (req: Request) => Promise<Response>)(new Request(`http://localhost${path}`, init));

test('generate works while Redis is down', async () => {
  geminiCalls = [];
  const res = await call('/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-forwarded-for': '1.1.1.1' },
    body: JSON.stringify({ tags: ['quiet'], groupSize: 2 }),
  });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.game, 'ゲーム名: テスト\n遊び方: ルール');
  assert.equal(geminiCalls.length, 1);
  assert.ok(!geminiCalls[0].includes('1.5-flash'));
  assert.ok(!geminiCalls[0].includes('key='), 'key must be sent as header, not URL');
});

test('fallback limiter still limits', async () => {
  let last = 0;
  for (let i = 0; i < 11; i++) {
    const res = await call('/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-forwarded-for': '2.2.2.2' },
      body: JSON.stringify({ tags: ['quiet'] }),
    });
    last = res.status;
  }
  assert.equal(last, 429);
});

test('health does not expose the key', async () => {
  const res = await call('/api/health');
  const text = await res.text();
  assert.equal(res.status, 200);
  assert.ok(!text.includes('test-key'));
  assert.ok(!text.includes('keyPreview'));
});
