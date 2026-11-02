// Submits an App Store version for review via the App Store Connect API.
//
//   node submit.mjs <metadata.yaml> [buildNumber]            # dry run: check and report only
//   node submit.mjs <metadata.yaml> [buildNumber] --submit   # attach the build and submit
//
// Uses bundleId and version.versionString from the YAML. The build is the
// newest processed build of that version unless a number is given.
// Not covered by the API (do these in App Store Connect first): App Privacy
// answers, age rating questionnaire changes, pricing and availability.
//
// Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8.
import { readFileSync } from 'node:fs';
import { parse } from 'yaml';
import { makeToken, createClient } from './sync.mjs';

const EDITABLE = new Set(['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED']);
const OPEN_SUBMISSION = ['WAITING_FOR_REVIEW', 'IN_REVIEW', 'UNRESOLVED_ISSUES'];

export async function submitForReview(api, { bundleId, versionString, buildNumber, submit = false, log = console.log }) {
  const app = (await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`)).data[0];
  if (!app) throw new Error(`No app with bundle id ${bundleId}`);

  const version = (await api('GET',
    `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${encodeURIComponent(versionString)}`,
  )).data[0];
  if (!version) throw new Error(`Version ${versionString} does not exist in App Store Connect`);
  const state = version.attributes.appStoreState ?? version.attributes.appVersionState;
  log(`version ${versionString}: ${state}, release: ${version.attributes.releaseType ?? '?'}`);

  const open = (await api('GET',
    `/v1/reviewSubmissions?filter[app]=${app.id}&filter[platform]=IOS&filter[state]=${OPEN_SUBMISSION.join(',')}`,
  )).data;
  if (open.length) {
    log(`already submitted (${open[0].attributes.state}); nothing to do`);
    return { submitted: false, alreadyOpen: true };
  }
  if (!EDITABLE.has(state)) throw new Error(`Version ${versionString} cannot be submitted in state ${state}`);

  const buildQuery = `/v1/builds?filter[app]=${app.id}&filter[preReleaseVersion.version]=${encodeURIComponent(versionString)}` +
    `&filter[processingState]=VALID&sort=-uploadedDate&limit=1` +
    (buildNumber ? `&filter[version]=${encodeURIComponent(buildNumber)}` : '');
  const build = (await api('GET', buildQuery)).data[0];
  if (!build) throw new Error(`No processed build ${buildNumber ?? ''} for ${versionString}`.replace('  ', ' '));
  if (build.attributes.usesNonExemptEncryption == null) {
    throw new Error(`Build ${build.attributes.version} has no export compliance answer (run the TestFlight workflow first)`);
  }
  log(`build: ${build.attributes.version} (uploaded ${build.attributes.uploadedDate ?? '?'})`);

  if (!submit) {
    log('dry run: would attach this build and submit for review (run with --submit)');
    return { submitted: false, buildId: build.id };
  }

  await api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, {
    data: { type: 'builds', id: build.id },
  });
  log('build attached');

  // Reuse a draft submission if one is lying around (e.g. from the web UI).
  let submission = (await api('GET',
    `/v1/reviewSubmissions?filter[app]=${app.id}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW`,
  )).data[0];
  if (!submission) {
    submission = (await api('POST', '/v1/reviewSubmissions', {
      data: {
        type: 'reviewSubmissions',
        attributes: { platform: 'IOS' },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    })).data;
  }
  const items = (await api('GET', `/v1/reviewSubmissions/${submission.id}/items`)).data;
  const hasVersion = items.some((i) => i.relationships?.appStoreVersion?.data?.id === version.id);
  if (!hasVersion) {
    await api('POST', '/v1/reviewSubmissionItems', {
      data: {
        type: 'reviewSubmissionItems',
        relationships: {
          reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
          appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
        },
      },
    });
  }
  await api('PATCH', `/v1/reviewSubmissions/${submission.id}`, {
    data: { type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true } },
  });
  log(`submitted ${versionString} (${build.attributes.version}) for review`);
  return { submitted: true, buildId: build.id, submissionId: submission.id };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const submit = args.includes('--submit');
  const [file, buildNumber] = args.filter((a) => a !== '--submit');
  if (!file) {
    console.error('usage: node submit.mjs <metadata.yaml> [buildNumber] [--submit]');
    process.exit(2);
  }
  for (const name of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_P8']) {
    if (!process.env[name]) {
      console.error(`${name} is not set`);
      process.exit(2);
    }
  }
  const meta = parse(readFileSync(file, 'utf8'));
  const api = createClient(makeToken({
    keyId: process.env.ASC_KEY_ID,
    issuerId: process.env.ASC_ISSUER_ID,
    privateKey: process.env.ASC_KEY_P8,
  }));
  submitForReview(api, {
    bundleId: meta.bundleId,
    versionString: meta.version.versionString,
    buildNumber: buildNumber || undefined,
    submit,
  }).catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
