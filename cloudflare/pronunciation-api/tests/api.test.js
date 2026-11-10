import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Miniflare} from 'miniflare';
import {importSQL} from '../scripts/import.js';
import {key,validate,checksum} from '../src/dictionary.js';
import worker from '../src/index.js';
const rules=JSON.parse(readFileSync('../../App/Resources/EMA/pronunciations.json','utf8'));
const migration=readFileSync('migrations/0001_dictionary.sql','utf8');
const mf=new Miniflare({modules:true,modulesRules:[{type:'ESModule',include:['**/*.js']}],scriptPath:'src/index.js',compatibilityDate:'2026-08-06',d1Databases:['DB']});
const db=await mf.getD1Database('DB');
// D1 exec is line based, so keep the trigger on one line.
await db.exec(migration.replace(/\n/g,' '));
const seed=await importSQL(rules);
const req=(path,init)=>mf.dispatchFetch('https://speak.ekatech.net/api/v1/'+path,init);
test('local D1 and real Worker runtime',async t=>{
 await t.test('empty dictionary returns 503',async()=>assert.equal((await req('pronunciations')).status,503));
 await t.test('atomic import and repeated seed',async()=>{
  await db.exec(seed); await db.exec(seed);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM dictionary_metadata').first()).n,1);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM pronunciations').first()).n,rules.length);
 });
 await t.test('health',async()=>assert.deepEqual(await (await req('health')).json(),{status:'ok'}));
 await t.test('version, complete dictionary, checksum, 304 and HEAD',async()=>{
  const r=await req('pronunciations'),s=await r.json();
  assert.equal(r.status,200); assert.equal(s.version,1); assert.equal(s.rules.length,rules.length);
  assert.equal(s.checksum,await checksum(validate(rules)));
  const meta=await (await req('pronunciations/version')).json(); assert.equal(meta.checksum,s.checksum);
  for(const tag of [r.headers.get('etag'),'W/'+r.headers.get('etag'),'*']) {
   const unchanged=await req('pronunciations',{headers:{'If-None-Match':tag}});
   assert.equal(unchanged.status,304); assert.equal(await unchanged.text(),'');
  }
  assert.equal(await (await req('pronunciations',{method:'HEAD'})).text(),'');
 });
 await t.test('write methods, CORS and payloads rejected',async()=>{
  for(const method of ['POST','PUT','PATCH','DELETE']) assert.equal((await req('pronunciations',{method})).status,405);
  assert.equal((await req('pronunciations?text=private')).status,400);
  assert.equal((await req('pronunciations',{headers:{Origin:'https://evil.test'}})).status,403);
  assert.equal((await req('missing')).status,404);
 });
 await t.test('changed content publishes next version, preserves old snapshot',async()=>{
  await db.exec(await importSQL([...rules,{word:'Test',pronunciation:'test',category:'Test'}]));
  await db.exec(await importSQL([...rules,{word:'Test',pronunciation:'test',category:'Test'}]));
  const versions=await db.prepare('SELECT version,rule_count FROM dictionary_metadata ORDER BY version').all();
  assert.deepEqual(versions.results,[{version:1,rule_count:rules.length},{version:2,rule_count:rules.length+1}]);
 });
 await mf.dispose();
});
test('normalization matches Swift brand and Turkish policy',()=>{
 for(const [a,b] of [['İphone','iphone'],['IŞIK','ışık'],['İĞDE','iğde'],['ÇÖĞÜŞ','çöğüş'],['I','i'],['İ','i']]) assert.equal(key(a),b);
 assert.notEqual(key('Işık'),key('İşik'));
 assert.throws(()=>validate([...rules,rules[0]])); assert.throws(()=>validate([]));
});
test('D1 failure, oversized response and malformed snapshot are safe',async()=>{
 const request=new Request('https://speak.ekatech.net/api/v1/pronunciations'),ctx={waitUntil(){}};
 for(const DB of [ {prepare(){throw Error('private identifier');}}, {prepare(){return {first:async()=>({version:1,updated_at:'now',payload:'{}'})};}}, {prepare(){return {first:async()=>({version:1,updated_at:'now',payload:JSON.stringify({schemaVersion:1,ruleCount:1,rules:['x'.repeat(1048576)]})})};}} ]) {
  const r=await worker.fetch(request,{DB},ctx); assert.equal(r.status,503); assert.ok(!(await r.text()).includes('private'));
 }
});
test('edge cache avoids repeated D1 reads; conditional hit returns 304',async()=>{
 const entries=new Map(),pending=[]; let reads=0;
 globalThis.caches={default:{match:async r=>entries.get(r.url)?.clone(),put:async(r,v)=>{entries.set(r.url,v);}}};
 const DB={prepare(){reads++;return {first:async()=>({version:1,updated_at:'2026-11-10T00:00:00Z',payload:JSON.stringify({schemaVersion:1,ruleCount:1,rules:[rules[0]],checksum:'abc'})})};}};
 const ctx={waitUntil:p=>pending.push(p)},url='https://speak.ekatech.net/api/v1/pronunciations';
 const r=await worker.fetch(new Request(url),{DB},ctx); await Promise.all(pending);
 assert.equal((await worker.fetch(new Request(url,{headers:{'If-None-Match':r.headers.get('etag')}}),{DB},ctx)).status,304);
 assert.equal(reads,1); delete globalThis.caches;
});
test('rate limiter rejects excess requests',async()=>{
 assert.equal((await worker.fetch(new Request('https://speak.ekatech.net/api/v1/health'),{RATE_LIMITER:{limit:async()=>({success:false})}},{})).status,429);
});
