import {readFileSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {validate, key, checksum} from '../src/dictionary.js';
export const hash = text => createHash('sha256').update(text).digest('hex');
const quote = s => "'" + s.replaceAll("'", "''") + "'";
export async function releaseV2(records, version) {
 if (!Number.isSafeInteger(version) || version < 1 || !records.length || records.length>100000) throw Error('Invalid release');
 // Imported CMU candidates cannot pass this explicit review gate.
 const rules = records.map(r => {
  if(r.status!=='verified' || !r.provenance || !r.reviewedBy || r.confidence<0.95) throw Error('Unreviewed record');
  return validate([r])[0];
 });
 if(new Set(rules.map(r=>key(r.word))).size!==rules.length) throw Error('Duplicate');
 rules.sort((a,b)=>key(a.word)<key(b.word)?-1:1);
 // Stable hash buckets avoid shifting every subsequent chunk when a word is added.
 const buckets=new Map();
 for(const r of rules) {const bucket=hash(key(r.word)).slice(0,2); if(!buckets.has(bucket)) buckets.set(bucket,[]); buckets.get(bucket).push(r);}
 const groups=[];
 for(const [,rs] of [...buckets].sort()) { let group=[]; for(const r of rs) {if(Buffer.byteLength(JSON.stringify([...group,r]))>48000) {groups.push(group); group=[];} group.push(r);} if(group.length) groups.push(group); }
 const chunks=groups.map(rs=>{const payload=JSON.stringify(rs); if(Buffer.byteLength(payload)>262144) throw Error('Chunk overflow'); return {hash:hash(payload),bytes:Buffer.byteLength(payload),ruleCount:rs.length,payload};});
 const manifest={schemaVersion:2,version,locale:'tr-TR',ruleCount:rules.length,checksum:await checksum(rules),chunks:chunks.map(({payload,...c})=>c)};
 if(Buffer.byteLength(JSON.stringify(manifest))>262144 || chunks.length>1024 || chunks.reduce((n,c)=>n+c.bytes,0)>32000000) throw Error('Release exceeds mobile budget');
 const statements=chunks.map(c=>`INSERT OR IGNORE INTO dictionary_chunks(hash,payload) VALUES(${quote(c.hash)},${quote(c.payload)});`);
 statements.push(`INSERT INTO dictionary_releases(version,manifest) VALUES(${version},${quote(JSON.stringify(manifest))});`);
 // Only staging is promoted by the generator. Execute promotion separately after review.
 statements.push(`INSERT INTO dictionary_channels(channel,version) VALUES('staging',${version}) ON CONFLICT(channel) DO UPDATE SET version=excluded.version;`);
 return {manifest,sql:statements.join('\n')};
}
export function promoteSQL(version,channel='stable') {
 if(!Number.isSafeInteger(version)||version<1||!['stable','staging'].includes(channel)) throw Error('Invalid promotion');
 return `INSERT INTO dictionary_channels(channel,version) SELECT '${channel}',version FROM dictionary_releases WHERE version=${version} ON CONFLICT(channel) DO UPDATE SET version=excluded.version;`;
}
if(process.argv[1]?.endsWith('/release-v2.js')) {
 const {sql,manifest}=await releaseV2(JSON.parse(readFileSync(process.argv[2],'utf8')),Number(process.argv[3]));
 writeFileSync(process.argv[4]||'staging-v2.sql',sql); console.log(JSON.stringify(manifest));
}
