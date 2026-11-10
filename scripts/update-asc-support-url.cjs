// Update only the existing EMA App Store support URL. Never print credentials.
const {createPrivateKey, sign} = require('node:crypto');
const fs = require('node:fs');
const bundle = 'net.ekatech.ema-lightning-ios.627Y9N4Q6P';
const target = 'https://speak.ekatech.net/privacy';
async function main() {
  const {ASC_KEY_ID:kid, ASC_ISSUER_ID:iss, ASC_PRIVATE_KEY:raw} = process.env;
  if (!kid || !iss || !raw) throw Error('Required Apple credentials are missing');
  const key = createPrivateKey(raw.replace(/\r\n/g, '\n').trim() + '\n');
  const enc = x => Buffer.from(JSON.stringify(x)).toString('base64url');
  const now = Math.floor(Date.now()/1000);
  const unsigned = enc({alg:'ES256',kid,typ:'JWT'}) + '.' + enc({iss,iat:now-30,exp:now+300,aud:'appstoreconnect-v1'});
  const jwt = unsigned + '.' + sign('sha256',Buffer.from(unsigned),{key,dsaEncoding:'ieee-p1363'}).toString('base64url');
  async function request(path, method='GET', body) {
    const r = await fetch('https://api.appstoreconnect.apple.com'+path, {
      method, headers:{Authorization:'Bearer '+jwt,Accept:'application/json','Content-Type':'application/json'},
      body:body ? JSON.stringify(body) : undefined, signal:AbortSignal.timeout(20000)
    });
    const data = await r.json();
    console.log(method+' '+path+': HTTP '+r.status);
    if (!r.ok) throw Error(JSON.stringify((data.errors||[]).map(e=>({code:e.code,title:e.title,detail:e.detail}))).slice(0,1500));
    return data;
  }
  const apps = await request('/v1/apps?filter[bundleId]='+encodeURIComponent(bundle));
  const app = apps.data.filter(a=>a.attributes.bundleId===bundle);
  if (app.length!==1) throw Error('Expected exactly one EMA app');
  const versions = await request('/v1/apps/'+app[0].id+'/appStoreVersions?filter[platform]=IOS&limit=20');
  const selected = versions.data.filter(v=>v.attributes.versionString==='1.0');
  if (selected.length!==1) throw Error('Expected exactly one existing iOS 1.0 store version');
  const version = selected[0];
  console.log('Current review: '+JSON.stringify({id:version.id,version:version.attributes.versionString,state:version.attributes.appStoreState}));
  const locals = await request('/v1/appStoreVersions/'+version.id+'/appStoreVersionLocalizations');
  if (!locals.data.length) throw Error('No existing store localizations');
  for (const l of locals.data) {
    console.log('Before: '+JSON.stringify({id:l.id,locale:l.attributes.locale,supportUrl:l.attributes.supportUrl}));
    if (l.attributes.supportUrl!==target) {
      await request('/v1/appStoreVersionLocalizations/'+l.id,'PATCH',{
        data:{type:'appStoreVersionLocalizations',id:l.id,attributes:{supportUrl:target}}
      });
    }
    const verified = await request('/v1/appStoreVersionLocalizations/'+l.id);
    if (verified.data.attributes.supportUrl!==target) throw Error('Support URL read-back verification failed');
    console.log('Verified support URL: '+JSON.stringify({locale:verified.data.attributes.locale,supportUrl:verified.data.attributes.supportUrl}));
    if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'Verified '+verified.data.attributes.locale+' support URL: '+target+'\n');
  }
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
