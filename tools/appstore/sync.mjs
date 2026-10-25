// Applies appstore/metadata.yaml to App Store Connect via the official API.
//
//   node sync.mjs <metadata.yaml>            # dry run: print the diff only
//   node sync.mjs <metadata.yaml> --apply    # write the changes
//
// Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (contents of the .p8 file).
// Only fields present in the YAML are changed. Never submits for review.
import { readFileSync } from 'node:fs';
import { dirname, resolve, basename } from 'node:path';
import { createHash, createPrivateKey, sign } from 'node:crypto';
import { parse, stringify } from 'yaml';

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

function printChanges(label, current, changes, log = console.log) {
  const keys = Object.keys(changes);
  if (keys.length === 0) {
    log(`= ${label}: no changes`);
    return;
  }
  log(`~ ${label}:`);
  for (const key of keys) {
    const before = JSON.stringify(current?.[key] ?? null);
    const after = JSON.stringify(changes[key]);
    log(`    ${key}: ${before} -> ${after}`);
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

export async function sync(api, meta, opts = {}) {
  const { apply, log = console.log } = opts;
  const mode = apply ? 'APPLY' : 'DRY RUN';
  log(`[${mode}] ${meta.bundleId}`);

  const apps = await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(meta.bundleId)}`);
  const app = apps.data[0];
  if (!app) throw new Error(`App not found for bundle id ${meta.bundleId}`);

  let pending = 0;

  // --- App Store version ---
  const { versionString, ...versionAttrs } = meta.version || {};
  if (versionString) pending += await syncVersion(api, app, versionString, versionAttrs, meta, { ...opts, log });

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
      printChanges(`appInfo[${locale}]`, loc.attributes, changes, log);
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
async function syncVersion(api, app, versionString, versionAttrs, meta, opts) {
  const { apply, log } = opts;
  let pending = 0;

  const versions = await api(
    'GET',
    `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${encodeURIComponent(versionString)}`
  );
  let version = versions.data[0];
  if (!version) {
    log(`+ appStoreVersion ${versionString}: will be created`);
    pending++;
    if (!apply) {
      // A new version starts with a copy of the live version's text, so the
      // dry run compares against that to show what will actually change.
      const all = await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
      const live = all.data.find((v) => ['READY_FOR_SALE', 'READY_FOR_DISTRIBUTION'].includes(v.attributes.appStoreState ?? v.attributes.appVersionState));
      if (!live) return pending;
      log(`  (comparing with live version ${live.attributes.versionString})`);
      const liveLocs = await api('GET', `/v1/appStoreVersions/${live.id}/appStoreVersionLocalizations`);
      for (const [locale, entry] of Object.entries(meta.localizations || {})) {
        const { screenshots, ...wanted } = entry || {};
        const loc = liveLocs.data.find((l) => l.attributes.locale === locale);
        if (!loc) {
          log(`+ localization[${locale}]: will be created`);
          continue;
        }
        // whatsNew is not copied to a new version, so compare it with empty.
        const base = { ...loc.attributes, whatsNew: null };
        const changes = diff(base, wanted);
        printChanges(`localization[${locale}]`, base, changes, log);
        if (Object.keys(changes).length) pending++;
        if (screenshots) pending += await syncScreenshots(api, loc.id, locale, screenshots, opts);
      }
      return pending;
    }
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
    printChanges(`appStoreVersion ${versionString}`, version.attributes, changes, log);
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
  for (const [locale, entry] of Object.entries(meta.localizations || {})) {
    // screenshots are handled separately; everything else is a text attribute
    const { screenshots, ...wanted } = entry || {};
    let loc = vlocs.data.find((l) => l.attributes.locale === locale);
    if (!loc) {
      log(`+ localization[${locale}]: will be created`);
      pending++;
      if (!apply) continue;
      const created = await api('POST', '/v1/appStoreVersionLocalizations', {
        data: {
          type: 'appStoreVersionLocalizations',
          attributes: { locale, ...wanted },
          relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
        },
      });
      loc = created.data;
    } else {
      const changes = diff(loc.attributes, wanted);
      printChanges(`localization[${locale}]`, loc.attributes, changes, log);
      if (Object.keys(changes).length) {
        pending++;
        if (apply) {
          await api('PATCH', `/v1/appStoreVersionLocalizations/${loc.id}`, {
            data: { type: 'appStoreVersionLocalizations', id: loc.id, attributes: changes },
          });
        }
      }
    }
    if (screenshots) pending += await syncScreenshots(api, loc.id, locale, screenshots, opts);
  }

  return pending;
}

// --- Snapshot ---
// Current values in App Store Connect, in the same shape as metadata.yaml,
// so they can be copied into the file and edited.
const APP_INFO_FIELDS = ['name', 'subtitle', 'privacyPolicyUrl', 'privacyChoicesUrl'];
const VERSION_LOC_FIELDS = ['description', 'keywords', 'promotionalText', 'supportUrl', 'marketingUrl', 'whatsNew'];

function pick(attrs, fields) {
  return Object.fromEntries(fields.filter((f) => attrs[f] != null && attrs[f] !== '').map((f) => [f, attrs[f]]));
}

export async function snapshot(api, bundleId) {
  const app = (await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`)).data[0];
  if (!app) throw new Error(`App not found for bundle id ${bundleId}`);
  const out = { bundleId };

  const versions = (await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`)).data;
  const stateOf = (v) => v.attributes.appStoreState ?? v.attributes.appVersionState;
  const version = versions.find((v) => EDITABLE_VERSION_STATES.has(stateOf(v))) ||
    versions.find((v) => ['READY_FOR_SALE', 'READY_FOR_DISTRIBUTION'].includes(stateOf(v))) || versions[0];
  if (version) {
    out.version = { versionString: version.attributes.versionString, state: stateOf(version), ...pick(version.attributes, ['copyright', 'releaseType']) };
  }

  const infos = (await api('GET', `/v1/apps/${app.id}/appInfos`)).data;
  const info = infos.find((i) => !['READY_FOR_DISTRIBUTION', 'READY_FOR_SALE'].includes(i.attributes.state ?? i.attributes.appStoreState)) || infos[0];
  if (info) {
    out.appInfo = {};
    for (const l of (await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations`)).data) {
      out.appInfo[l.attributes.locale] = pick(l.attributes, APP_INFO_FIELDS);
    }
  }

  if (version) {
    out.localizations = {};
    for (const l of (await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data) {
      const entry = pick(l.attributes, VERSION_LOC_FIELDS);
      const sets = (await api('GET', `/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets`)).data;
      if (sets.length) {
        entry.screenshots = {};
        for (const set of sets) {
          const shots = (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data;
          entry.screenshots[set.attributes.screenshotDisplayType] = shots.map((x) => x.attributes.fileName);
        }
      }
      out.localizations[l.attributes.locale] = entry;
    }
  }
  return out;
}

// --- Screenshots ---
// For each display type listed in the YAML, make the set match the listed
// files exactly (same images, same order). Display types not listed are left
// alone. Files are compared by MD5, so unchanged images are not re-uploaded.
function loadFile(baseDir, path) {
  const full = resolve(baseDir, path);
  const data = readFileSync(full);
  return { path, fileName: basename(full), data, md5: createHash('md5').update(data).digest('hex') };
}

async function defaultUpload(op, data) {
  const res = await fetch(op.url, {
    method: op.method,
    headers: Object.fromEntries((op.requestHeaders || []).map((h) => [h.name, h.value])),
    body: data.subarray(op.offset, op.offset + op.length),
  });
  if (!res.ok) throw new Error(`upload ${op.method} -> ${res.status}`);
}

async function syncScreenshots(api, locId, locale, wantedSets, opts) {
  const { apply, log, baseDir = '.', upload = defaultUpload, sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = opts;
  let pending = 0;
  const sets = locId ? (await api('GET', `/v1/appStoreVersionLocalizations/${locId}/appScreenshotSets`)).data : [];

  for (const [displayType, paths] of Object.entries(wantedSets)) {
    const files = paths.map((p) => loadFile(baseDir, p));
    let set = sets.find((s) => s.attributes.screenshotDisplayType === displayType);
    const existing = set ? (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data : [];
    const existingMd5 = existing.map((e) => e.attributes.sourceFileChecksum);
    const label = `screenshots[${locale}][${displayType}]`;

    if (JSON.stringify(existingMd5) === JSON.stringify(files.map((f) => f.md5))) {
      log(`= ${label}: no changes`);
      continue;
    }
    const toUpload = files.filter((f) => !existingMd5.includes(f.md5));
    const toDelete = existing.filter((e) => !files.some((f) => f.md5 === e.attributes.sourceFileChecksum));
    log(`~ ${label}: upload ${toUpload.length}, delete ${toDelete.length}, then order as listed (${files.map((f) => f.fileName).join(', ')})`);
    pending++;
    if (!apply) continue;

    if (!set) {
      set = (await api('POST', '/v1/appScreenshotSets', {
        data: {
          type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: displayType },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: locId } } },
        },
      })).data;
    }

    const idByMd5 = Object.fromEntries(existing.map((e) => [e.attributes.sourceFileChecksum, e.id]));
    for (const f of toUpload) {
      const reserved = (await api('POST', '/v1/appScreenshots', {
        data: {
          type: 'appScreenshots',
          attributes: { fileName: f.fileName, fileSize: f.data.length },
          relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } },
        },
      })).data;
      for (const op of reserved.attributes.uploadOperations || []) await upload(op, f.data);
      await api('PATCH', `/v1/appScreenshots/${reserved.id}`, {
        data: { type: 'appScreenshots', id: reserved.id, attributes: { uploaded: true, sourceFileChecksum: f.md5 } },
      });
      // Wait for Apple to process the image so size errors show up here.
      for (let i = 0; i < 30; i++) {
        const state = (await api('GET', `/v1/appScreenshots/${reserved.id}`)).data.attributes.assetDeliveryState?.state;
        if (state === 'COMPLETE') break;
        if (state === 'FAILED') throw new Error(`${label}: Apple rejected ${f.path} (check the image size for ${displayType})`);
        await sleep(2000);
      }
      idByMd5[f.md5] = reserved.id;
    }
    for (const e of toDelete) await api('DELETE', `/v1/appScreenshots/${e.id}`);
    await api('PATCH', `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
      data: files.map((f) => ({ type: 'appScreenshots', id: idByMd5[f.md5] })),
    });
  }
  return pending;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [file, flag] = process.argv.slice(2);
  if (!file) {
    console.error('usage: node sync.mjs <metadata.yaml> [--apply | --show]');
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
  const run = flag === '--show'
    ? snapshot(createClient(token), meta.bundleId).then((snap) => {
        console.log('# Current values in App Store Connect (screenshots: file names only)');
        console.log(stringify(snap, { lineWidth: 0 }));
      })
    : sync(createClient(token), meta, { apply: flag === '--apply', baseDir: dirname(resolve(file)) });
  run.catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
