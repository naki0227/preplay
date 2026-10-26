// node --test tools/monitor/check.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runChecks, format } from './check.mjs';

const config = { BACKEND_URL: 'https://api.test/', SUPABASE_URL: 'https://db.test', SUPABASE_ANON_KEY: 'pub' };

function fakeFetch(overrides = {}) {
  const calls = [];
  const fn = async (url, init = {}) => {
    calls.push({ url, init });
    for (const [prefix, make] of Object.entries(overrides)) if (url.startsWith(prefix)) return make();
    if (url === 'https://api.test/api/health') return Response.json({ status: 'ok', hasApiKey: true });
    if (url === 'https://api.test/api/generate') return Response.json({ game: 'ゲーム名: テスト\n遊び方: ルール' });
    if (url.startsWith('https://db.test/rest/v1/games')) return Response.json([{ id: 'x' }]);
    throw new Error(`unexpected ${url}`);
  };
  fn.calls = calls;
  return fn;
}

test('all green', async () => {
  const fetch = fakeFetch();
  const results = await runChecks(config, { fetch, retryDelayMs: 0 });
  assert.ok(results.every((r) => r.ok), format(results));
  const gen = fetch.calls.find((c) => c.url.endsWith('/api/generate'));
  assert.equal(gen.init.headers['x-preplay-monitor'], '1');
  const db = fetch.calls.find((c) => c.url.startsWith('https://db.test'));
  assert.equal(db.init.headers.apikey, 'pub');
});

test('reports a Gemini outage (e.g. credits used up) and a missing key', async () => {
  const fetch = fakeFetch({
    'https://api.test/api/generate': () => new Response('{"error":"Failed to generate game"}', { status: 500 }),
    'https://api.test/api/health': () => Response.json({ status: 'ok', hasApiKey: false }),
  });
  const results = await runChecks(config, { fetch, retryDelayMs: 0 });
  assert.deepEqual(results.map((r) => r.ok), [false, false, true]);
  assert.match(format(results), /❌ AIで遊びを作る.*HTTP 500/);
});

test('retries once before failing', async () => {
  let n = 0;
  const fetch = fakeFetch({
    'https://db.test': () => (n++ === 0 ? new Response('', { status: 503 }) : Response.json([{ id: 'x' }])),
  });
  const results = await runChecks(config, { fetch, retryDelayMs: 0 });
  assert.ok(results[2].ok);
});

test('network errors count as failures', async () => {
  const fetch = fakeFetch({ 'https://db.test': () => { throw new TypeError('fetch failed'); } });
  const results = await runChecks(config, { fetch, retryDelayMs: 0 });
  assert.equal(results[2].ok, false);
  assert.match(results[2].error, /fetch failed/);
});
