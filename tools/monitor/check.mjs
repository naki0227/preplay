// Checks that what the app needs is working, the way the app uses it:
//   1. backend health (Gemini key present)
//   2. AI generation end to end (one real Gemini call)
//   3. Supabase serves the official games with the public key
// Reads the URLs and the public key from config/app_config.json.
// Prints one line per check and exits 1 if any failed.
//
//   node tools/monitor/check.mjs
import { readFile } from 'node:fs/promises';

export async function runChecks(config, { fetch = globalThis.fetch, retryDelayMs = 30_000 } = {}) {
  const backend = config.BACKEND_URL.replace(/\/$/, '');
  const checks = [
    ['サーバーの状態 (/api/health)', async () => {
      const res = await fetch(`${backend}/api/health`, { signal: AbortSignal.timeout(15_000) });
      if (res.status !== 200) return `HTTP ${res.status}`;
      const body = await res.json();
      if (!body.hasApiKey) return 'Gemini の API キーが設定されていません';
    }],
    ['AIで遊びを作る (/api/generate)', async () => {
      const res = await fetch(`${backend}/api/generate`, {
        method: 'POST',
        // x-preplay-monitor keeps this check out of the daily numbers.
        headers: { 'Content-Type': 'application/json', 'x-preplay-monitor': '1' },
        body: JSON.stringify({ tags: ['all'], groupSize: 2 }),
        signal: AbortSignal.timeout(30_000),
      });
      if (res.status !== 200) return `HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`;
      const body = await res.json();
      if (!/ゲーム名/.test(body.game ?? '')) return `想定外の応答: ${JSON.stringify(body).slice(0, 200)}`;
    }],
    ['みんなの遊び (Supabase)', async () => {
      const url = `${config.SUPABASE_URL}/rest/v1/games?select=id&origin=eq.Preplay%20Official&limit=1`;
      const res = await fetch(url, { headers: { apikey: config.SUPABASE_ANON_KEY }, signal: AbortSignal.timeout(15_000) });
      if (res.status !== 200) return `HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`;
      const rows = await res.json();
      if (!Array.isArray(rows) || rows.length === 0) return '公式の遊びが1件も読めません';
    }],
  ];

  const results = [];
  for (const [name, check] of checks) {
    // One retry so a single network blip does not open an issue.
    let error;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        error = await check();
      } catch (e) {
        error = String(e?.message ?? e);
      }
      if (!error) break;
      if (attempt === 0) await new Promise((r) => setTimeout(r, retryDelayMs));
    }
    results.push({ name, ok: !error, error });
  }
  return results;
}

export function format(results) {
  return results.map((r) => (r.ok ? `✅ ${r.name}` : `❌ ${r.name}: ${r.error}`)).join('\n');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const config = JSON.parse(await readFile(new URL('../../config/app_config.json', import.meta.url), 'utf8'));
  const results = await runChecks(config);
  console.log(format(results));
  process.exitCode = results.every((r) => r.ok) ? 0 : 1;
}
