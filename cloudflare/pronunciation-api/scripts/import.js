import {readFileSync,writeFileSync} from 'node:fs';
import {validate,checksum,key,MAX_BYTES} from '../src/dictionary.js';
export async function importSQL(input) {
 const rules=validate(input), hash=await checksum(rules);
 const payload=JSON.stringify({schemaVersion:1,locale:'tr-TR',ruleCount:rules.length,checksum:hash,rules:rules.map(r=>({...r,normalizedWord:key(r.word)}))});
 if(Buffer.byteLength(payload)>MAX_BYTES-256) throw Error('Snapshot too large');
 const quote=s=>"'"+s.replaceAll("'","''")+"'";
 return `INSERT INTO dictionary_metadata(version,updated_at,schema_version,rule_count,checksum,payload) SELECT COALESCE(MAX(version),0)+1,strftime('%Y-%m-%dT%H:%M:%SZ','now'),1,${rules.length},${quote(hash)},${quote(payload)} FROM dictionary_metadata HAVING COALESCE((SELECT checksum FROM dictionary_metadata ORDER BY version DESC LIMIT 1),'')<>${quote(hash)};`;
}
if(process.argv[1]?.endsWith('/import.js')) writeFileSync(process.argv[3]||'seed.sql',await importSQL(JSON.parse(readFileSync(process.argv[2]||'../../App/Resources/EMA/pronunciations.json','utf8'))));
