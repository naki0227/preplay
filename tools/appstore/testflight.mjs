// Makes an uploaded build installable from TestFlight by the team.
//
//   node testflight.mjs <bundleId> [buildNumber]   # default: the newest build
//
// 1. waits until App Store Connect has processed the build
// 2. answers export compliance (the app only uses HTTPS: exempt) if unanswered
// 3. makes sure the internal group "内部テスト" exists with access to every
//    build, and that every App Store Connect user of the team is in it
//
// Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8. The workflow log is public, so
// nothing about the testers (e-mail, name) is printed.
import { makeToken, createClient } from './sync.mjs';

export const GROUP_NAME = '内部テスト';

export async function prepareTestFlight(apiFactory, bundleId, buildNumber, opts = {}) {
  const log = opts.log ?? console.log;
  const sleep = opts.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  const timeoutMs = opts.timeoutMs ?? 40 * 60_000;
  let api = apiFactory();

  const apps = await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  const app = apps.data[0];
  if (!app) throw new Error(`No app with bundle id ${bundleId}`);

  // 1. Wait for the build to show up and finish processing.
  const query = `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1` +
    (buildNumber ? `&filter[version]=${encodeURIComponent(buildNumber)}` : '');
  const start = Date.now();
  let build;
  for (;;) {
    api = apiFactory(); // tokens last 15 minutes
    build = (await api('GET', query)).data[0];
    const state = build?.attributes?.processingState;
    if (state === 'VALID') break;
    if (state === 'FAILED' || state === 'INVALID') {
      throw new Error(`Build ${build.attributes.version} is ${state} in App Store Connect`);
    }
    if (Date.now() - start > timeoutMs) {
      throw new Error(`Build ${buildNumber ?? '(newest)'} was not processed in time (state: ${state ?? 'not found yet'})`);
    }
    log(`waiting: build ${buildNumber ?? '(newest)'} is ${state ?? 'not in App Store Connect yet'}`);
    await sleep(30_000);
  }
  log(`build ${build.attributes.version}: processed`);

  // 2. Export compliance. Unanswered builds show "Missing Compliance" and cannot be tested.
  if (build.attributes.usesNonExemptEncryption == null) {
    await api('PATCH', `/v1/builds/${build.id}`, {
      data: { type: 'builds', id: build.id, attributes: { usesNonExemptEncryption: false } },
    });
    log('export compliance: answered (no non-exempt encryption)');
  } else {
    log(`export compliance: already answered (${build.attributes.usesNonExemptEncryption})`);
  }

  // 3. Internal group with access to all builds.
  const groups = await api('GET', `/v1/betaGroups?filter[app]=${app.id}&filter[name]=${encodeURIComponent(GROUP_NAME)}`);
  let group = groups.data.find((g) => g.attributes.isInternalGroup);
  if (!group) {
    group = (await api('POST', '/v1/betaGroups', {
      data: {
        type: 'betaGroups',
        attributes: { name: GROUP_NAME, isInternalGroup: true, hasAccessToAllBuilds: true },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    })).data;
    log(`group "${GROUP_NAME}": created`);
  }
  if (!group.attributes.hasAccessToAllBuilds) {
    await api('POST', `/v1/betaGroups/${group.id}/relationships/builds`, {
      data: [{ type: 'builds', id: build.id }],
    });
    log(`group "${GROUP_NAME}": build added`);
  }

  // Everyone on the team (App Store Connect users) as an internal tester.
  const users = (await api('GET', '/v1/users?limit=200')).data;
  const inGroup = new Set(
    (await api('GET', `/v1/betaGroups/${group.id}/betaTesters?limit=200`)).data
      .map((t) => t.attributes.email?.toLowerCase()),
  );
  let added = 0;
  for (const user of users) {
    const email = user.attributes.username;
    if (!email || inGroup.has(email.toLowerCase())) continue;
    const existing = (await api('GET', `/v1/betaTesters?filter[email]=${encodeURIComponent(email)}`)).data[0];
    if (existing) {
      await api('POST', `/v1/betaGroups/${group.id}/relationships/betaTesters`, {
        data: [{ type: 'betaTesters', id: existing.id }],
      });
    } else {
      await api('POST', '/v1/betaTesters', {
        data: {
          type: 'betaTesters',
          attributes: { email, firstName: user.attributes.firstName, lastName: user.attributes.lastName },
          relationships: { betaGroups: { data: [{ type: 'betaGroups', id: group.id }] } },
        },
      });
    }
    added++;
  }
  log(`testers: ${added} added, ${inGroup.size} already in "${GROUP_NAME}"`);
  return { buildId: build.id, groupId: group.id, added };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [bundleId, buildNumber] = process.argv.slice(2);
  if (!bundleId) {
    console.error('usage: node testflight.mjs <bundleId> [buildNumber]');
    process.exit(2);
  }
  for (const name of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_P8']) {
    if (!process.env[name]) {
      console.error(`${name} is not set`);
      process.exit(2);
    }
  }
  const apiFactory = () => createClient(makeToken({
    keyId: process.env.ASC_KEY_ID,
    issuerId: process.env.ASC_ISSUER_ID,
    privateKey: process.env.ASC_KEY_P8,
  }));
  prepareTestFlight(apiFactory, bundleId, buildNumber || undefined).catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
