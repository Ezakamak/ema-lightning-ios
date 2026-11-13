import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Miniflare} from 'miniflare';
import {releaseV2,promoteSQL,hash} from '../scripts/release-v2.js';
const seeds=JSON.parse(readFileSync('../../App/Resources/EMA/pronunciations.json'));
const approved=rs=>rs.map(r=>({...r,status:'verified',confidence:1,reviewedBy:'existing-seed',provenance:'bundled-v1'}));
test('v2 staging, atomic publication, immutable chunks, rollback, v1 preservation',async()=>{
 const mf=new Miniflare({modules:true,modulesRules:[{type:'ESModule',include:['**/*.js']}],scriptPath:'src/index.js',compatibilityDate:'2026-08-06',d1Databases:['DB']});
 try {
 const db=await mf.getD1Database('DB');
 for(const file of ['0001_dictionary.sql','0002_shards.sql']) await db.exec(readFileSync('migrations/'+file,'utf8').replace(/\n/g,' '));
 const req=p=>mf.dispatchFetch('https://speak.ekatech.net/api/v2/pronunciations/'+p);
 const first=await releaseV2(approved(seeds),1);
 for(const line of first.sql.split('\n')) await db.exec(line);
 assert.equal((await req('manifest')).status,503);
 await db.exec(promoteSQL(1));
 const response=await req('manifest'),m=await response.json();
 assert.equal(m.ruleCount,158);
 assert.equal((await req('manifest',{headers:{}})).status,200);
 for(const c of m.chunks) {
  const r=await req('chunks/'+c.hash),bytes=await r.text();
  assert.equal(hash(bytes),c.hash); assert.equal(Buffer.byteLength(bytes),c.bytes);
 }
 await assert.rejects(db.exec("INSERT INTO dictionary_releases(version,manifest) VALUES(2,'{\"schemaVersion\":2,\"version\":2,\"ruleCount\":1,\"chunks\":[{\"hash\":\"missing\",\"bytes\":10}]}');"));
 assert.equal((await (await req('manifest')).json()).version,1);
 const second=await releaseV2(approved([...seeds,{word:'Example',pronunciation:'igzampıl',category:'Test'}]),2);
 for(const line of second.sql.split('\n')) await db.exec(line);
 await db.exec(promoteSQL(2)); assert.equal((await (await req('manifest')).json()).version,2);
 // Monotonic rollback: republish known good contents under a new version.
 const rollback=await releaseV2(approved(seeds),3);
 for(const line of rollback.sql.split('\n')) await db.exec(line);
 await db.exec(promoteSQL(3)); assert.equal((await (await req('manifest')).json()).checksum,first.manifest.checksum);
 assert.equal((await db.prepare('SELECT count(*) n FROM dictionary_metadata').first()).n,0);
 await assert.rejects(db.exec("UPDATE dictionary_chunks SET payload='[]'"));
 } finally {await mf.dispose();}
});
test('100k release capacity, deterministic output and fail closed quality gate',async()=>{
 const rules=Array.from({length:100000},(_,i)=>({word:'Term'+i,pronunciation:'terim',category:'Capacity'}));
 const start=performance.now(),release=await releaseV2(approved(rules),1);
 assert.equal(release.manifest.ruleCount,100000);assert.ok(release.manifest.chunks.length<=256);
 console.log(JSON.stringify({release100kMilliseconds:performance.now()-start,manifestBytes:Buffer.byteLength(JSON.stringify(release.manifest)),maxChunkBytes:Math.max(...release.manifest.chunks.map(c=>c.bytes))}));
 await assert.rejects(releaseV2([{...seeds[0],status:'needs_review'}],1));
 await assert.rejects(releaseV2(approved([seeds[0],seeds[0]]),1));
});
