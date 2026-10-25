// Applies appstore/metadata.yaml to App Store Connect via the official API.
//
//   node sync.mjs <metadata.yaml>            # dry run: print the diff only
//   node sync.mjs <metadata.yaml> --apply    # write the changes
//
// Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contents of the .p8 file).
// Only fields present in the YAML are changed. Never submits for review.
import { readFileSync } from 'node:fs';
import { createPrivateKey, sign } from 'node:crypto';
import { parse } from 'yaml';

const API = 'https://api.appstoreconnect.apple.com';

function base64url(input) {
  return Buffer.from(input).toString('base64url');
}

export function makeToken({ keyId, issuerId, privateKey }, now = Math.floor(Date.now() / 1000)) {
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 15 * 60, // Apple allows at most 20 minutes
    aud: 'appstoreconnect-v1',
  }));
  const signature = sign('sha256', Buffer.from(`${header}.${payload}`), {
    key: createPrivateKey(privateKey),
    dsaEncoding: 'ieee-p1363',
  });
  return `${header}.${payload}.${base64url(signature)}`;
}

export function createClient(token, fetchImpl = fetch) {
  return async function api(method, path, body) {
    const res = await fetchImpl(`${API}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) {
      throw new Error(`${method} ${path} -> ${res.status}: ${(await res.text()).slice(0, 1000)}`);
    }
    return res.status === 204 ? null : res.json();
  };
}

// Fields that differ between `current` and `wanted` (only keys in `wanted`).
export function diff(current, wanted) {
  const changes = {};
  for (const [key, value] of Object.entries(wanted || {})) {
    if ((current?.[key] ?? null) !== (value ?? null)) changes[key] = value;
  }
  return changes;
}

function printChanges(label, current, changes) {
  const keys = Object.keys(changes);
  if (keys.length === 0) {
    console.log(`= ${label}: no changes`);
    return;
  }
  console.log(`~ ${label}:`);
  for (const key of keys) {
    const before = JSON.stringify(current?.[key] ?? null);
    const after = JSON.stringify(changes[key]);
    console.log(`    ${key}: ${before} -> ${after}`);
  }
}

// States in which App Store Connect accepts edits to version metadata.
const EDITABLE_VERSION_STATES = new Set([
  'PREPARE_FOR_SUBMISSION',
  'DEVELOPER_REJECTED',
  'REJECTED',
  'METADATA_REJECTED',
  'INVALID_BINARY',
]);

export async function sync(api, meta, { apply, log = console.log } = {}) {
  const mode = apply ? 'APPLY' : 'DRY RUN';
  log(`[${mode}] ${meta.bundleId}`);

  const apps = await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(meta.bundleId)}`);
  const app = apps.data[0];
  if (!app) throw new Error(`App not found for bundle id ${meta.bundleId}`);

  let pending = 0;

  // --- App Store version ---
  const { versionString, ...versionAttrs } = meta.version || {};
  if (versionString) pending += await syncVersion(api, app, versionString, versionAttrs, meta, { apply, log });

  // --- App information (privacy policy URL etc.) ---
  if (meta.appInfo) {
    const infos = await api('GET', `/v1/apps/${app.id}/appInfos`);
    // Prefer the app info that is being prepared; the live one is read-only.
    const info =
      infos.data.find((i) => !['READY_FOR_DISTRIBUTION', 'READY_FOR_SALE'].includes(i.attributes.state ?? i.attributes.appStoreState)) ||
      infos.data[0];
    const locs = await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations`);
    for (const [locale, wanted] of Object.entries(meta.appInfo)) {
      const loc = locs.data.find((l) => l.attributes.locale === locale);
      if (!loc) {
        const have = locs.data.map((l) => l.attributes.locale).join(', ');
        throw new Error(`appInfo locale "${locale}" not found (available: ${have})`);
      }
      const changes = diff(loc.attributes, wanted);
      printChanges(`appInfo[${locale}]`, loc.attributes, changes);
      if (Object.keys(changes).length) {
        pending++;
        if (apply) {
          await api('PATCH', `/v1/appInfoLocalizations/${loc.id}`, {
            data: { type: 'appInfoLocalizations', id: loc.id, attributes: changes },
          });
        }
      }
    }
  }

  log(apply ? `Applied ${pending} change(s).` : `${pending} change(s) would be applied.`);
  return pending;
}

// Creates the version if needed and syncs its localizations.
// App info only becomes editable once a new version exists, so this runs first.
async function syncVersion(api, app, versionString, versionAttrs, meta, { apply, log }) {
  let pending = 0;

  const versions = await api(
    'GET',
    `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${encodeURIComponent(versionString)}`
  );
  let version = versions.data[0];
  if (!version) {
    log(`+ appStoreVersion ${versionString}: will be created`);
    pending++;
    if (!apply) return pending; // localizations do not exist yet; nothing more to diff
    const created = await api('POST', '/v1/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: { platform: 'IOS', versionString, ...versionAttrs },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    });
    version = created.data;
  } else {
    const state = version.attributes.appStoreState ?? version.attributes.appVersionState;
    if (!EDITABLE_VERSION_STATES.has(state)) {
      throw new Error(`Version ${versionString} is ${state} and cannot be edited. Bump version.versionString.`);
    }
    const changes = diff(version.attributes, versionAttrs);
    printChanges(`appStoreVersion ${versionString}`, version.attributes, changes);
    if (Object.keys(changes).length) {
      pending++;
      if (apply) {
        await api('PATCH', `/v1/appStoreVersions/${version.id}`, {
          data: { type: 'appStoreVersions', id: version.id, attributes: changes },
        });
      }
    }
  }

  const vlocs = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  for (const [locale, wanted] of Object.entries(meta.localizations || {})) {
    const loc = vlocs.data.find((l) => l.attributes.locale === locale);
    if (!loc) {
      log(`+ localization[${locale}]: will be created`);
      pending++;
      if (apply) {
        await api('POST', '/v1/appStoreVersionLocalizations', {
          data: {
            type: 'appStoreVersionLocalizations',
            attributes: { locale, ...wanted },
            relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
          },
        });
      }
      continue;
    }
    const changes = diff(loc.attributes, wanted);
    printChanges(`localization[${locale}]`, loc.attributes, changes);
    if (Object.keys(changes).length) {
      pending++;
      if (apply) {
        await api('PATCH', `/v1/appStoreVersionLocalizations/${loc.id}`, {
          data: { type: 'appStoreVersionLocalizations', id: loc.id, attributes: changes },
        });
      }
    }
  }

  return pending;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [file, flag] = process.argv.slice(2);
  if (!file) {
    console.error('usage: node sync.mjs <metadata.yaml> [--apply]');
    process.exit(2);
  }
  for (const name of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_P8']) {
    if (!process.env[name]) {
      console.error(`${name} is not set`);
      process.exit(2);
    }
  }
  const meta = parse(readFileSync(file, 'utf8'));
  const token = makeToken({
    keyId: process.env.ASC_KEY_ID,
    issuerId: process.env.ASC_ISSUER_ID,
    privateKey: process.env.ASC_KEY_P8,
  });
  sync(createClient(token), meta, { apply: flag === '--apply' }).catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
