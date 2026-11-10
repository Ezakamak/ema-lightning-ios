// Read-only preflight. Never print keys, tokens, response bodies or exception messages.
const { createPrivateKey, sign } = require('node:crypto');
const fs = require('node:fs');
function fail(message) { console.error(message); process.exitCode = 1; }
const encoded = value => Buffer.from(JSON.stringify(value)).toString('base64url');
async function main() {
  const { ASC_KEY_ID: kid, ASC_ISSUER_ID: iss, ASC_PRIVATE_KEY: raw, APPLE_TEAM_ID: team } = process.env;
  if (!kid || !iss || !raw || !team) throw new Error('Missing Apple secret; no build started.');
  if (!/^[A-Z0-9]{10}$/.test(kid) || !/^[A-Z0-9]{10}$/.test(team) ||
      !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(iss))
    throw new Error('Apple identifiers have invalid syntax (values withheld).');
  const pem = raw.replace(/\r\n/g, '\n').trim() + '\n';
  let key;
  try { key = createPrivateKey(pem); } catch { throw new Error('Invalid PEM: expected complete PKCS#8 .p8 with real line breaks.'); }
  if (!pem.startsWith('-----BEGIN PRIVATE KEY-----') || key.asymmetricKeyType !== 'ec' ||
      key.asymmetricKeyDetails.namedCurve !== 'prime256v1')
    throw new Error('Expected a PKCS#8 EC P-256 App Store Connect key for ES256.');
  console.log('Private key: valid PKCS#8 EC P-256 PEM');
  function token(claims) {
    const now = Math.floor(Date.now() / 1000);
    const payload = encoded({ alg: 'ES256', kid, typ: 'JWT' }) + '.' +
      encoded({ ...claims, iat: now - 30, exp: now + 300, aud: 'appstoreconnect-v1' });
    return payload + '.' + sign('sha256', Buffer.from(payload), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  }
  async function check(path, jwt, label) {
    let response;
    try {
      response = await fetch('https://api.appstoreconnect.apple.com' + path, {
        headers: { Authorization: 'Bearer ' + jwt, Accept: 'application/json' },
        signal: AbortSignal.timeout(20000)
      });
    } catch { throw new Error(label + ': network failure; no build started.'); }
    console.log(label + ': HTTP ' + response.status);
    if (process.env.GITHUB_STEP_SUMMARY)
      fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${label}: HTTP ${response.status}\n\n`);
    if (response.status === 403) fail(label + ': authenticated but forbidden; check API role and Certificates, Identifiers & Profiles access.');
    if (response.status === 429 || response.status >= 500) fail(label + ': Apple service/rate-limit failure; no credentials diagnosis can be inferred.');
    return { status: response.status, data: response.ok ? await response.json() : null };
  }
  const jwt = token({ iss });
  const apps = await check('/v1/apps?limit=1', jwt, 'App Store Connect');
  const profiles = await check('/v1/profiles?limit=1', jwt, 'Provisioning');
  if (apps.status === 401) {
    const individual = await check('/v1/apps?limit=1', token({ sub: 'user' }), 'Individual key diagnostic');
    fail(individual.status === 200
      ? 'Individual key detected: Team issuer authentication is incompatible. Team API key is required for this provisioning workflow.'
      : 'Team JWT rejected: Key ID/private key pairing, issuer, revocation or account state cannot be distinguished from HTTP 401 alone.');
  }
  if (apps.status !== 200 || profiles.status !== 200) { process.exitCode = 1; return; }
  const bundle = 'net.ekatech.ema-lightning-ios.627Y9N4Q6P';
  const app = await check('/v1/apps?filter[bundleId]=' + bundle + '&limit=1', jwt, 'Target app');
  const ids = await check('/v1/bundleIds?filter[identifier]=' + bundle + '&limit=1', jwt, 'Bundle ID');
  const certs = await check('/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=1', jwt, 'Distribution certificates');
  if ([app, ids, certs].some(r => r.status !== 200) || !app.data?.data?.length || !ids.data?.data?.length) {
    fail('Target app / Bundle ID / certificate access unavailable for this team.'); return;
  }
  const exactApp = app.data.data.find(item => item.attributes?.bundleId === bundle);
  const exactBundle = ids.data.data.find(item => item.attributes?.identifier === bundle);
  if (!exactApp || !exactBundle) {
    // Bundle identifiers are public app metadata, never credential values.
    console.log('Expected Bundle ID: ' + bundle);
    console.log('Returned app Bundle IDs: ' + app.data.data.map(item => item.attributes?.bundleId).join(', '));
    console.log('Returned portal identifiers: ' + ids.data.data.map(item => item.attributes?.identifier).join(', '));
    fail('Apple returned no exact matching app / Bundle ID. Check the existing App Store Connect app record before building.'); return;
  }
  console.log('Target app and Bundle ID exist. API read access does not prove cloud signing permission or local signing identity availability.');
  const allBuilds = [];
  let buildPath = '/v1/builds?filter[app]=' + exactApp.id + '&limit=200';
  while (buildPath) {
    const page = await check(buildPath, jwt, 'Build inventory');
    if (page.status !== 200) throw new Error('Cannot determine highest Apple build.');
    allBuilds.push(...page.data.data);
    const next = page.data.links?.next;
    if (next && new URL(next).origin !== 'https://api.appstoreconnect.apple.com') throw new Error('Unexpected pagination origin');
    buildPath = next ? new URL(next).pathname + new URL(next).search : null;
  }
  const parts = v => v.split('.').map(Number);
  const compare = (a,b) => { const x=parts(a), y=parts(b); for(let i=0;i<3;i++) {const d=(x[i]||0)-(y[i]||0); if(d) return d;} return 0; };
  const highest = allBuilds.map(b=>b.attributes.version).sort(compare).at(-1) || '0';
  console.log('Highest Apple build: ' + highest);
  const nextBuild = String(parts(highest)[0] + 1);
  if (process.env.GITHUB_ENV) fs.appendFileSync(process.env.GITHUB_ENV, 'NEXT_BUILD_NUMBER=' + nextBuild + '\n');
  if (process.env.BUILD_NUMBER && compare(process.env.BUILD_NUMBER, highest) <= 0) throw new Error('Requested build must exceed highest Apple build.');
  const versions = await check('/v1/apps/' + exactApp.id + '/appStoreVersions?filter[platform]=IOS&limit=20', jwt, 'App Store versions');
  for (const v of versions.data?.data || []) {
    console.log('App Store version: ' + JSON.stringify({id:v.id, version:v.attributes.versionString, state:v.attributes.appStoreState}));
    const localizations = await check('/v1/appStoreVersions/' + v.id + '/appStoreVersionLocalizations', jwt, 'Version metadata');
    for (const l of localizations.data?.data || []) console.log('Metadata: ' + JSON.stringify({id:l.id,locale:l.attributes.locale,description:!!l.attributes.description,keywords:!!l.attributes.keywords,supportUrl:l.attributes.supportUrl,marketingUrl:l.attributes.marketingUrl}));
  }
  if (process.env.VERIFY_BUILD_NUMBER) {
    const expected = process.env.VERIFY_BUILD_NUMBER;
    if (!/^[0-9.]+$/.test(expected)) throw new Error('Invalid build number to inspect.');
    const result = await check('/v1/builds?filter[app]=' + exactApp.id + '&filter[version]=' + expected + '&limit=10', jwt, 'Uploaded build');
    const build = result.data?.data?.find(item => item.attributes?.version === expected);
    if (!build) throw new Error('Uploaded build is not visible in App Store Connect yet.');
    console.log('Apple build metadata: ' + JSON.stringify({id:build.id,...build.attributes}));
    const beta = await check('/v1/builds/' + build.id + '/buildBetaDetail', jwt, 'TestFlight availability');
    console.log('TestFlight: ' + JSON.stringify(beta.data?.data?.attributes));
    const state = build.attributes.processingState;
    console.log('Build ' + expected + ': Apple processing state = ' + state);
    if (process.env.GITHUB_STEP_SUMMARY)
      fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, 'Build ' + expected + ': processing state **' + state + '**. Tester access is managed separately.\n');
    if (state === 'FAILED' || state === 'INVALID') throw new Error('Apple processing failed; inspect the App Store Connect build details.');
  }
  // Write only after every preflight check passes, for Xcode and altool.
  if (process.env.ASC_KEY_DIRECTORY) {
    if (!/^[0-9]+$/.test(exactApp.id)) throw new Error('Target Apple app ID is invalid.');
    fs.appendFileSync(process.env.GITHUB_ENV, 'ASC_APP_ID=' + exactApp.id + '\n');
    fs.mkdirSync(process.env.ASC_KEY_DIRECTORY, { recursive: true, mode: 0o700 });
    fs.writeFileSync(process.env.ASC_KEY_DIRECTORY + '/AuthKey_' + kid + '.p8', pem, { mode: 0o600 });
  }
}
main().catch(error => { fail(error.message); });
