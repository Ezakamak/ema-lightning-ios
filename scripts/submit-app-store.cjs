// Submit only the explicitly authorized EMA 1.2 / build 15; never rebuild or release it.
const {createPrivateKey,sign}=require('node:crypto');
const fs=require('node:fs');
const VERSION='1.2', BUILD='15', BUNDLE='net.ekatech.ema-lightning-ios.627Y9N4Q6P';
const NOTES={
 tr:'• Daha büyük telaffuz sözlükleri için destek ve daha verimli kelime eşleştirme.\n• Telaffuz sözlüğü güncellemelerinde güvenilirlik iyileştirmeleri.\n• Örnek metin artık yalnızca ilk açılışta gösteriliyor. Sonraki açılışlarda metin kutusu boş başlıyor.',
 en:'• Improved pronunciation dictionary support and more efficient word matching.\n• Added support for larger dictionaries with reliable, integrity-checked updates.\n• The sample text now appears only on first launch. Subsequent launches start with an empty text box.'
};
async function main(){
 if(process.env.SUBMIT_APP_STORE_VERSION!==VERSION) throw Error('Explicit 1.2 submission input required');
 const kid=process.env.ASC_KEY_ID,iss=process.env.ASC_ISSUER_ID,pem=process.env.ASC_PRIVATE_KEY;
 if(!kid||!iss||!pem) throw Error('Missing existing Apple credentials');
 const key=createPrivateKey(pem.replace(/\r\n/g,'\n'));
 if(key.asymmetricKeyType!=='ec'||key.asymmetricKeyDetails.namedCurve!=='prime256v1') throw Error('Expected EC P-256 key');
 const enc=o=>Buffer.from(JSON.stringify(o)).toString('base64url');
 const now=Math.floor(Date.now()/1000),unsigned=enc({alg:'ES256',kid,typ:'JWT'})+'.'+enc({iss,iat:now-30,exp:now+600,aud:'appstoreconnect-v1'});
 const jwt=unsigned+'.'+sign('sha256',Buffer.from(unsigned),{key,dsaEncoding:'ieee-p1363'}).toString('base64url');
 async function call(method,path,body){
  const url=new URL(path,'https://api.appstoreconnect.apple.com');
  if(url.origin!=='https://api.appstoreconnect.apple.com'||!url.pathname.startsWith('/v1/')) throw Error('Unexpected API target');
  const r=await fetch(url,{method,headers:{Authorization:'Bearer '+jwt,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(30000)});
  const data=r.status===204?{}:await r.json();
  if(!r.ok){console.error(JSON.stringify({operation:method+' '+url.pathname,status:r.status,errors:data.errors?.map(({code,title,detail,source})=>({code,title,detail,source}))}));throw Error('Apple rejected '+method+' '+url.pathname);}
  return data;
 }
 async function list(path){const result=[];let next=path+(path.includes('?')?'&':'?')+'limit=200';while(next){const p=await call('GET',next);result.push(...p.data);next=p.links?.next;}return result;}
 const rel=(type,id)=>({data:{type,id}});
 const apps=await list('/v1/apps?filter[bundleId]='+encodeURIComponent(BUNDLE));
 if(apps.length!==1||apps[0].attributes.bundleId!==BUNDLE)throw Error('Exact EMA app not found');
 const app=apps[0];
 const versions=await list('/v1/apps/'+app.id+'/appStoreVersions?filter[platform]=IOS&filter[versionString]='+VERSION);
 if(versions.length!==1)throw Error('Existing 1.2 version required; no other version will be changed');
 const version=versions[0],state=version.attributes.appStoreState;
 const builds=await list('/v1/builds?filter[app]='+app.id+'&filter[version]='+BUILD);
 if(builds.length!==1||builds[0].attributes.processingState!=='VALID')throw Error('Exactly one VALID build 15 required');
 const build=builds[0];
 const train=(await call('GET','/v1/builds/'+build.id+'/preReleaseVersion')).data;
 if(train.attributes.version!==VERSION||train.attributes.platform!=='IOS')throw Error('Build does not belong to iOS 1.2');
 const selected=(await call('GET','/v1/appStoreVersions/'+version.id+'/build')).data;
 if(selected&&selected.id!==build.id)throw Error('Another build is selected; preserving existing selection');
 if(['WAITING_FOR_REVIEW','IN_REVIEW','PENDING_DEVELOPER_RELEASE','READY_FOR_SALE'].includes(state)){
  if(selected?.id!==build.id)throw Error('Submission does not select expected build');
  console.log(JSON.stringify({version:VERSION,build:BUILD,state,alreadySubmitted:true}));return;
 }
 if(!['PREPARE_FOR_SUBMISSION','READY_FOR_REVIEW'].includes(state))throw Error('Version is not editable: '+state);
 const locales=await list('/v1/appStoreVersions/'+version.id+'/appStoreVersionLocalizations');
 if(!locales.length)throw Error('Existing localized metadata required');
 for(const l of locales){
  const language=l.attributes.locale.split('-')[0],notes=NOTES[language];
  if(!l.attributes.description||!l.attributes.supportUrl)throw Error('Incomplete existing localization: '+l.attributes.locale);
  if(!l.attributes.whatsNew?.trim()){
   if(!notes)throw Error('No approved release notes for locale '+l.attributes.locale);
   await call('PATCH','/v1/appStoreVersionLocalizations/'+l.id,{data:{type:'appStoreVersionLocalizations',id:l.id,attributes:{whatsNew:notes}}});
   console.log('Release notes set for '+l.attributes.locale);
  }else console.log('Preserved existing release notes for '+l.attributes.locale);
 }
 // Approval must not automatically publish a version that was only authorized for review.
 await call('PATCH','/v1/appStoreVersions/'+version.id,{data:{type:'appStoreVersions',id:version.id,attributes:{releaseType:'MANUAL'}}});
 if(!selected)await call('PATCH','/v1/appStoreVersions/'+version.id+'/relationships/build',rel('builds',build.id));
 const submissions=await list('/v1/apps/'+app.id+'/reviewSubmissions');
 let submission;
 for(const s of submissions.filter(s=>s.attributes.platform==='IOS'&&s.attributes.state==='READY_FOR_REVIEW')){
  const items=await list('/v1/reviewSubmissions/'+s.id+'/items?include=appStoreVersion');
  const target=items.some(i=>i.relationships?.appStoreVersion?.data?.id===version.id);
  if(target&&items.length!==1)throw Error('Draft contains other review items; leaving it unchanged');
  if(target||items.length===0){submission=s;break;}
 }
 if(!submission)submission=(await call('POST','/v1/reviewSubmissions',{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:rel('apps',app.id)}}})).data;
 let items=await list('/v1/reviewSubmissions/'+submission.id+'/items?include=appStoreVersion');
 if(items.length===0)await call('POST','/v1/reviewSubmissionItems',{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:rel('reviewSubmissions',submission.id),appStoreVersion:rel('appStoreVersions',version.id)}}});
 items=await list('/v1/reviewSubmissions/'+submission.id+'/items?include=appStoreVersion');
 if(items.length!==1||items[0].relationships?.appStoreVersion?.data?.id!==version.id)throw Error('Unexpected review items; not submitting');
 await call('PATCH','/v1/reviewSubmissions/'+submission.id,{data:{type:'reviewSubmissions',id:submission.id,attributes:{submitted:true}}});
 const final=(await call('GET','/v1/reviewSubmissions/'+submission.id)).data;
 const latest=(await call('GET','/v1/appStoreVersions/'+version.id)).data;
 const result={version:VERSION,build:BUILD,submissionId:submission.id,submissionState:final.attributes.state,versionState:latest.attributes.appStoreState,releaseType:latest.attributes.releaseType};
 console.log(JSON.stringify(result));
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'```json\n'+JSON.stringify(result,null,2)+'\n```\n');
 if(!['WAITING_FOR_REVIEW','IN_REVIEW','COMPLETING'].includes(result.submissionState))throw Error('Apple has not confirmed review submission');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
