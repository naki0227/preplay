import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import { makeToken, sync, diff } from '../sync.mjs';

test('token is a valid ES256 JWT for App Store Connect', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const token = makeToken({ keyId: 'KEY123', issuerId: 'ISS', privateKey: pem }, 1000);
  const [h, p, s] = token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(h, 'base64url')), { alg: 'ES256', kid: 'KEY123', typ: 'JWT' });
  const payload = JSON.parse(Buffer.from(p, 'base64url'));
  assert.equal(payload.aud, 'appstoreconnect-v1');
  assert.ok(payload.exp - payload.iat <= 20 * 60);
  assert.ok(verify('sha256', Buffer.from(`${h}.${p}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url')));
});

test('diff only reports keys that are set and different', () => {
  assert.deepEqual(diff({ a: '1', b: '2', c: '3' }, { a: '1', b: 'x' }), { b: 'x' });
});

function fakeApi({ versionExists, appInfoState = 'PREPARE_FOR_SUBMISSION' }) {
  const calls = [];
  const api = async (method, path, body) => {
    calls.push({ method, path, body });
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'APP' }] };
    if (path === '/v1/apps/APP/appStoreVersions?filter[platform]=IOS') {
      return { data: [{ id: 'LIVEVER', attributes: { versionString: '1.0', appStoreState: 'READY_FOR_SALE' } }] };
    }
    if (path.startsWith('/v1/apps/APP/appStoreVersions')) {
      return { data: versionExists ? [{ id: 'VER', attributes: { versionString: '2.0.1', appStoreState: 'PREPARE_FOR_SUBMISSION' } }] : [] };
    }
    if (path === '/v1/appStoreVersions/LIVEVER/appStoreVersionLocalizations') {
      return { data: [{ id: 'LIVELOC', attributes: { locale: 'ja', description: 'live', supportUrl: 'https://enludus.vercel.app', whatsNew: 'old notes' } }] };
    }
    if (path === '/v1/appStoreVersions' && method === 'POST') return { data: { id: 'VER', attributes: {} } };
    if (path === '/v1/appStoreVersions/VER/appStoreVersionLocalizations') {
      return { data: [{ id: 'VLOC', attributes: { locale: 'ja', description: 'old', supportUrl: 'https://enludus.vercel.app', whatsNew: null } }] };
    }
    if (path === '/v1/apps/APP/appInfos') {
      return { data: [
        { id: 'LIVE', attributes: { state: 'READY_FOR_DISTRIBUTION' } },
        { id: 'NEXT', attributes: { state: appInfoState } },
      ] };
    }
    if (path === '/v1/appInfos/NEXT/appInfoLocalizations') {
      return { data: [{ id: 'ILOC', attributes: { locale: 'ja', name: 'Preplay', privacyPolicyUrl: null } }] };
    }
    if (method === 'PATCH') return { data: {} };
    throw new Error(`unexpected ${method} ${path}`);
  };
  return { api, calls };
}

const meta = parse(readFileSync(new URL('../../../appstore/metadata.yaml', import.meta.url), 'utf8'));

test('dry run never writes', async () => {
  const { api, calls } = fakeApi({ versionExists: true });
  const pending = await sync(api, meta, { apply: false, log: () => {} });
  assert.ok(pending > 0);
  assert.ok(calls.every((c) => c.method === 'GET'));
});

test('apply patches only changed fields, on the editable app info', async () => {
  const { api, calls } = fakeApi({ versionExists: true });
  await sync(api, meta, { apply: true, log: () => {} });
  const writes = calls.filter((c) => c.method !== 'GET');
  const vloc = writes.find((c) => c.path === '/v1/appStoreVersionLocalizations/VLOC');
  assert.equal(vloc.body.data.attributes.supportUrl, 'https://enludus.com');
  assert.ok(!('locale' in vloc.body.data.attributes));
  const iloc = writes.find((c) => c.path === '/v1/appInfoLocalizations/ILOC');
  assert.match(iloc.body.data.attributes.privacyPolicyUrl, /^https:\/\//);
  assert.ok(!writes.some((c) => /submission|reviewSubmissions/i.test(c.path)), 'must never submit for review');
});

test('apply creates the version when missing', async () => {
  const { api, calls } = fakeApi({ versionExists: false });
  await sync(api, meta, { apply: true, log: () => {} });
  const create = calls.find((c) => c.method === 'POST' && c.path === '/v1/appStoreVersions');
  assert.equal(create.body.data.attributes.versionString, '2.0.1');
  assert.equal(create.body.data.attributes.platform, 'IOS');
});

test('metadata version matches pubspec.yaml', () => {
  const pubspec = readFileSync(new URL('../../../pubspec.yaml', import.meta.url), 'utf8');
  const v = pubspec.match(/^version:\s*([0-9.]+)/m)[1];
  assert.equal(meta.version.versionString, v);
});

import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

function screenshotApi(existing) {
  const calls = [];
  let next = 0;
  const api = async (method, path, body) => {
    calls.push({ method, path, body });
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'APP' }] };
    if (path.startsWith('/v1/apps/APP/appStoreVersions')) {
      return { data: [{ id: 'VER', attributes: { appStoreState: 'PREPARE_FOR_SUBMISSION' } }] };
    }
    if (path === '/v1/appStoreVersions/VER/appStoreVersionLocalizations') {
      return { data: [{ id: 'VLOC', attributes: { locale: 'ja', keywords: 'old' } }] };
    }
    if (path === '/v1/appStoreVersionLocalizations/VLOC/appScreenshotSets') {
      return { data: [{ id: 'SET67', attributes: { screenshotDisplayType: 'APP_IPHONE_67' } }] };
    }
    if (path === '/v1/appScreenshotSets/SET67/appScreenshots') {
      return { data: existing.map((md5, i) => ({ id: `OLD${i}`, attributes: { sourceFileChecksum: md5 } })) };
    }
    if (method === 'POST' && path === '/v1/appScreenshots') {
      return { data: { id: `NEW${next++}`, attributes: { uploadOperations: [{ method: 'PUT', url: 'https://upload.invalid', offset: 0, length: body.data.attributes.fileSize, requestHeaders: [] }] } } };
    }
    if (method === 'GET' && path.startsWith('/v1/appScreenshots/')) {
      return { data: { attributes: { assetDeliveryState: { state: 'COMPLETE' } } } };
    }
    if (method === 'PATCH' || method === 'DELETE') return null;
    throw new Error(`unexpected ${method} ${path}`);
  };
  return { api, calls };
}

function tempImages(...contents) {
  const dir = mkdtempSync(join(tmpdir(), 'shots-'));
  const names = contents.map((c, i) => {
    writeFileSync(join(dir, `${i + 1}.png`), c);
    return `${i + 1}.png`;
  });
  const md5 = contents.map((c) => createHash('md5').update(c).digest('hex'));
  return { dir, names, md5 };
}

test('keywords are just another patched field', async () => {
  const { api, calls } = screenshotApi([]);
  await sync(api, { bundleId: 'x', version: { versionString: '2.0.1' }, localizations: { ja: { keywords: 'あそび,暇つぶし' } } }, { apply: true, log: () => {} });
  const patch = calls.find((c) => c.method === 'PATCH' && c.path === '/v1/appStoreVersionLocalizations/VLOC');
  assert.deepEqual(patch.body.data.attributes, { keywords: 'あそび,暇つぶし' });
});

test('screenshots: unchanged set does nothing', async () => {
  const img = tempImages('a', 'b');
  const { api, calls } = screenshotApi(img.md5);
  const meta = { bundleId: 'x', version: { versionString: '2.0.1' }, localizations: { ja: { screenshots: { APP_IPHONE_67: img.names } } } };
  const pending = await sync(api, meta, { apply: true, baseDir: img.dir, log: () => {} });
  assert.equal(pending, 0);
  assert.ok(calls.every((c) => c.method === 'GET'));
});

test('screenshots: uploads new, deletes removed, keeps unchanged, orders as listed', async () => {
  const img = tempImages('keep', 'new');
  const removed = createHash('md5').update('gone').digest('hex');
  const { api, calls } = screenshotApi([removed, img.md5[0]]);
  const uploads = [];
  const meta = { bundleId: 'x', version: { versionString: '2.0.1' }, localizations: { ja: { screenshots: { APP_IPHONE_67: img.names } } } };
  await sync(api, meta, { apply: true, baseDir: img.dir, log: () => {}, upload: async (op, data) => uploads.push(data.toString()), sleep: async () => {} });
  assert.deepEqual(uploads, ['new']);
  const commit = calls.find((c) => c.method === 'PATCH' && c.path === '/v1/appScreenshots/NEW0');
  assert.equal(commit.body.data.attributes.sourceFileChecksum, img.md5[1]);
  assert.ok(calls.some((c) => c.method === 'DELETE' && c.path === '/v1/appScreenshots/OLD0'));
  assert.ok(!calls.some((c) => c.method === 'DELETE' && c.path === '/v1/appScreenshots/OLD1'));
  const order = calls.find((c) => c.path === '/v1/appScreenshotSets/SET67/relationships/appScreenshots');
  assert.deepEqual(order.body.data.map((d) => d.id), ['OLD1', 'NEW0']);
});

test('screenshots: dry run does not upload', async () => {
  const img = tempImages('x');
  const { api, calls } = screenshotApi([]);
  const meta = { bundleId: 'x', version: { versionString: '2.0.1' }, localizations: { ja: { screenshots: { APP_IPHONE_67: img.names } } } };
  const pending = await sync(api, meta, { apply: false, baseDir: img.dir, log: () => {} });
  assert.equal(pending, 1);
  assert.ok(calls.every((c) => c.method === 'GET'));
});

test('dry run of a new version diffs against the live version', async () => {
  const { api, calls } = fakeApi({ versionExists: false });
  const lines = [];
  await sync(api, meta, { apply: false, log: (l) => lines.push(l) });
  assert.ok(calls.every((c) => c.method === 'GET'));
  const out = lines.join('\n');
  assert.match(out, /comparing with live version 1\.0/);
  assert.match(out, /supportUrl: "https:\/\/enludus\.vercel\.app" -> "https:\/\/enludus\.com"/);
  assert.match(out, /whatsNew: null ->/);
});
