// Preserve the previously shipped, approved baseline; this does not approve new candidates.
import {readFileSync,writeFileSync} from 'node:fs';
import {checksum} from '../cloudflare/pronunciation-api/src/dictionary.js';
const rules=JSON.parse(readFileSync(new URL('../App/Resources/EMA/pronunciations.json',import.meta.url)));
if(rules.length!==158 || await checksum(rules)!=='25c58ac2debbef6e9af15d3c5a895c8153f785070139897938e13ade0ef248b1') throw Error('Baseline changed; requires review');
writeFileSync(process.argv[2]||'build/reviewed-seed.json',JSON.stringify(rules.map(r=>({...r,status:'verified',confidence:1,reviewedBy:'legacy-shipped-baseline',provenance:'EMA bundled 158 rules; not a new auditory review'})),null,2)+'\n');
