import { test } from 'node:test';
import assert from 'node:assert/strict';
import { prepareTestFlight, GROUP_NAME } from '../testflight.mjs';

// A tiny fake of the App Store Connect API.
function fakeAsc({ states = ['VALID'], encryption = null, group = null, testers = [], users = [], existingTesters = [] } = {}) {
  const calls = [];
  let poll = 0;
  const api = async (method, path, body) => {
    calls.push({ method, path, body });
    if (method === 'GET' && path.startsWith('/v1/apps?')) return { data: [{ id: 'app1' }] };
    if (method === 'GET' && path.startsWith('/v1/builds?')) {
      const state = states[Math.min(poll++, states.length - 1)];
      return { data: state ? [{ id: 'b1', attributes: { version: '202610260654', processingState: state, usesNonExemptEncryption: encryption } }] : [] };
    }
    if (method === 'GET' && path.startsWith('/v1/betaGroups?')) return { data: group ? [group] : [] };
    if (method === 'POST' && path === '/v1/betaGroups') {
      return { data: { id: 'g1', attributes: body.data.attributes } };
    }
    if (method === 'GET' && path.startsWith('/v1/users')) return { data: users };
    if (method === 'GET' && path.includes('/betaTesters?limit')) return { data: testers };
    if (method === 'GET' && path.startsWith('/v1/betaTesters?')) {
      const email = decodeURIComponent(path.split('filter[email]=')[1]);
      return { data: existingTesters.filter((t) => t.attributes.email === email) };
    }
    return null;
  };
  return { api, calls };
}

const user = (email) => ({ attributes: { username: email, firstName: 'A', lastName: 'B' } });
const quiet = { log: () => {}, sleep: async () => {} };

test('waits for processing, answers compliance, creates the group and adds the team', async () => {
  const { api, calls } = fakeAsc({ states: [null, 'PROCESSING', 'VALID'], users: [user('owner@example.com')] });
  const r = await prepareTestFlight(() => api, 'com.preplay.preplay', '202610260654', quiet);
  assert.equal(r.added, 1);
  assert.equal(calls.filter((c) => c.path.startsWith('/v1/builds?')).length, 3);
  assert.ok(calls.find((c) => c.path.startsWith('/v1/builds?')).path.includes('filter[version]=202610260654'));
  const patch = calls.find((c) => c.method === 'PATCH');
  assert.equal(patch.body.data.attributes.usesNonExemptEncryption, false);
  const created = calls.find((c) => c.method === 'POST' && c.path === '/v1/betaGroups');
  assert.deepEqual(created.body.data.attributes, { name: GROUP_NAME, isInternalGroup: true, hasAccessToAllBuilds: true });
  const tester = calls.find((c) => c.method === 'POST' && c.path === '/v1/betaTesters');
  assert.equal(tester.body.data.relationships.betaGroups.data[0].id, 'g1');
});

test('does nothing twice: answered compliance, existing group with all builds, testers in place', async () => {
  const { api, calls } = fakeAsc({
    encryption: false,
    group: { id: 'g9', attributes: { isInternalGroup: true, hasAccessToAllBuilds: true } },
    users: [user('Owner@example.com')],
    testers: [{ attributes: { email: 'owner@example.com' } }],
  });
  const r = await prepareTestFlight(() => api, 'com.preplay.preplay', undefined, quiet);
  assert.equal(r.added, 0);
  assert.equal(calls.filter((c) => c.method !== 'GET').length, 0);
});

test('a group without access to all builds gets this build; a known tester is linked, not recreated', async () => {
  const { api, calls } = fakeAsc({
    encryption: false,
    group: { id: 'g9', attributes: { isInternalGroup: true, hasAccessToAllBuilds: false } },
    users: [user('owner@example.com')],
    existingTesters: [{ id: 't1', attributes: { email: 'owner@example.com' } }],
  });
  await prepareTestFlight(() => api, 'com.preplay.preplay', undefined, quiet);
  assert.ok(calls.find((c) => c.path === '/v1/betaGroups/g9/relationships/builds'));
  const link = calls.find((c) => c.path === '/v1/betaGroups/g9/relationships/betaTesters');
  assert.equal(link.body.data[0].id, 't1');
  assert.ok(!calls.find((c) => c.method === 'POST' && c.path === '/v1/betaTesters'));
});

test('fails clearly on a broken build or a timeout, and never prints e-mail addresses', async () => {
  const lines = [];
  const log = (l) => lines.push(l);
  await assert.rejects(
    prepareTestFlight(() => fakeAsc({ states: ['INVALID'] }).api, 'x', '1', { ...quiet, log }),
    /INVALID/,
  );
  await assert.rejects(
    prepareTestFlight(() => fakeAsc({ states: ['PROCESSING'] }).api, 'x', '1', { ...quiet, log, timeoutMs: -1 }),
    /not processed in time/,
  );
  const ok = fakeAsc({ users: [user('secret@example.com')] });
  await prepareTestFlight(() => ok.api, 'x', '1', { ...quiet, log });
  assert.ok(lines.every((l) => !l.includes('@')));
});
