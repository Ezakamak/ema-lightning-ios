import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {checksum,validate} from '../src/dictionary.js';
const base='https://speak.ekatech.net',results=[];
async function check(name,fn){await fn();results.push({name,passed:true});}
let full,etag;
await check('health 200',async()=>assert.deepEqual(await(await fetch(base+'/api/v1/health')).json(),{status:'ok'}));
await check('dictionary 200 and verified bundled checksum',async()=>{
 const r=await fetch(base+'/api/v1/pronunciations');assert.equal(r.status,200);full=await r.json();etag=r.headers.get('etag');
 const rules=validate(JSON.parse(readFileSync('../../App/Resources/EMA/pronunciations.json')));
 assert.equal(full.checksum,await checksum(rules));assert.equal(full.ruleCount,rules.length);assert.equal(full.rules.length,rules.length);
});
await check('version consistency',async()=>{const v=await(await fetch(base+'/api/v1/pronunciations/version')).json();assert.equal(v.version,full.version);assert.equal(v.checksum,full.checksum);});
await check('304 and cache',async()=>{const r=await fetch(base+'/api/v1/pronunciations',{headers:{'If-None-Match':etag}});assert.equal(r.status,304);assert.equal(await r.text(),'');assert.match(r.headers.get('cache-control'),/no-cache/);});
await check('all writes 405',async()=>{for(const method of ['POST','PUT','PATCH','DELETE'])assert.equal((await fetch(base+'/api/v1/pronunciations',{method})).status,405);});
await check('404, payload 400, CORS 403',async()=>{
 assert.equal((await fetch(base+'/api/v1/unknown')).status,404);
 assert.equal((await fetch(base+'/api/v1/pronunciations?text=test')).status,400);
 assert.equal((await fetch(base+'/api/v1/pronunciations',{headers:{Origin:'https://example.org'}})).status,403);
});
if(process.argv.includes('--compare-root')) await check('root unchanged',async()=>{
 const body=Buffer.from(await(await fetch(base+'/')).arrayBuffer());
 assert.equal(createHash('sha256').update(body).digest('hex'),createHash('sha256').update(readFileSync('/tmp/ema-root-before')).digest('hex'));
});
const evidence={testedAt:new Date().toISOString(),url:base+'/api/v1',version:full.version,ruleCount:full.ruleCount,checksum:full.checksum,results};
writeFileSync('evidence/live-smoke.json',JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(evidence,null,2));
