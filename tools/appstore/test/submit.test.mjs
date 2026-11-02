import { test } from 'node:test';
import assert from 'node:assert/strict';
import { submitForReview } from '../submit.mjs';

function fakeAsc({ state = 'PREPARE_FOR_SUBMISSION', open = [], draft = null, builds = [{ id: 'b1', attributes: { version: '202610260654', usesNonExemptEncryption: false } }], items = [] } = {}) {
  const calls = [];
  const api = async (method, path, body) => {
    calls.push({ method, path, body });
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'app1' }] };
    if (path.includes('/appStoreVersions?')) return { data: [{ id: 'v1', attributes: { appStoreState: state, releaseType: 'AFTER_APPROVAL' } }] };
    if (method === 'GET' && path.startsWith('/v1/reviewSubmissions?')) {
      return { data: path.includes('READY_FOR_REVIEW') && !path.includes('WAITING') ? (draft ? [draft] : []) : open };
    }
    if (path.startsWith('/v1/builds?')) return { data: builds };
    if (method === 'POST' && path === '/v1/reviewSubmissions') return { data: { id: 's1' } };
    if (path.endsWith('/items')) return { data: items };
    return null;
  };
  return { api, calls };
}
const quiet = { log: () => {} };
const opts = { bundleId: 'com.preplay.preplay', versionString: '2.0.1', ...quiet };

test('dry run checks everything and changes nothing', async () => {
  const { api, calls } = fakeAsc();
  const r = await submitForReview(api, opts);
  assert.equal(r.submitted, false);
  assert.equal(calls.filter((c) => c.method !== 'GET').length, 0);
  const q = calls.find((c) => c.path.startsWith('/v1/builds?')).path;
  assert.ok(q.includes('filter[preReleaseVersion.version]=2.0.1') && q.includes('filter[processingState]=VALID'));
});

test('submit: attaches the build, creates the submission with the version, submits', async () => {
  const { api, calls } = fakeAsc();
  const r = await submitForReview(api, { ...opts, submit: true, buildNumber: '202610260654' });
  assert.equal(r.submitted, true);
  const writes = calls.filter((c) => c.method !== 'GET').map((c) => `${c.method} ${c.path}`);
  assert.deepEqual(writes, [
    'PATCH /v1/appStoreVersions/v1/relationships/build',
    'POST /v1/reviewSubmissions',
    'POST /v1/reviewSubmissionItems',
    'PATCH /v1/reviewSubmissions/s1',
  ]);
  assert.equal(calls[calls.length - 1].body.data.attributes.submitted, true);
  assert.ok(calls.find((c) => c.path.startsWith('/v1/builds?')).path.includes('filter[version]=202610260654'));
});

test('reuses a draft submission that already has the version', async () => {
  const { api, calls } = fakeAsc({
    draft: { id: 'd1' },
    items: [{ relationships: { appStoreVersion: { data: { id: 'v1' } } } }],
  });
  await submitForReview(api, { ...opts, submit: true });
  const writes = calls.filter((c) => c.method !== 'GET').map((c) => `${c.method} ${c.path}`);
  assert.deepEqual(writes, ['PATCH /v1/appStoreVersions/v1/relationships/build', 'PATCH /v1/reviewSubmissions/d1']);
});

test('does not submit twice, and refuses unsafe states', async () => {
  const already = fakeAsc({ open: [{ id: 'x', attributes: { state: 'WAITING_FOR_REVIEW' } }] });
  assert.equal((await submitForReview(already.api, { ...opts, submit: true })).alreadyOpen, true);
  assert.equal(already.calls.filter((c) => c.method !== 'GET').length, 0);

  await assert.rejects(submitForReview(fakeAsc({ state: 'READY_FOR_SALE' }).api, { ...opts, submit: true }), /cannot be submitted/);
  await assert.rejects(submitForReview(fakeAsc({ builds: [] }).api, { ...opts, submit: true }), /No processed build/);
  await assert.rejects(
    submitForReview(fakeAsc({ builds: [{ id: 'b', attributes: { version: '1', usesNonExemptEncryption: null } }] }).api, { ...opts, submit: true }),
    /export compliance/,
  );
});
