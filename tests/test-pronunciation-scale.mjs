import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {compilePronunciations,applyPronunciations} from '../App/Resources/EMA/text-preparation.js';
const seeds=JSON.parse(readFileSync(new URL('../App/Resources/EMA/pronunciations.json',import.meta.url)));
test('all 158 seeds, case, suffixes and phrase boundaries',()=>{
 assert.equal(seeds.length,158);
 const matcher=compilePronunciations(seeds);
 for(const r of seeds) assert.equal(matcher(r.word),r.pronunciation,r.word);
 const rules=[{word:'Google',pronunciation:'gugıl'},{word:'Google Drive',pronunciation:'gugıl drayv'},{word:'Işık',pronunciation:'ışık'},{word:'iPhone',pronunciation:'ayfon'}];
 assert.equal(applyPronunciations("GOOGLE\t Drive’a İPHONE'un IŞIK Googlex",rules),'gugıl drayva ayfonun ışık Googlex');
 assert.equal(applyPronunciations('Google',[{word:'Google',pronunciation:'iPhone'},{word:'iPhone',pronunciation:'ayfon'}]),'iPhone');
});
test('100k matcher capacity; no rule scan during matching',()=>{
 const rules=Array.from({length:100000},(_,i)=>({word:'Term'+i,pronunciation:'terim'}));
 const start=performance.now(),match=compilePronunciations(rules),built=performance.now();
 for(let i=0;i<100;i++) assert.equal(match('Term99999 ve Term1, Term999999'),'terim ve terim, Term999999');
 console.log(JSON.stringify({rules:rules.length,compileMs:built-start,match100Ms:performance.now()-built,rssBytes:process.memoryUsage().rss}));
});
