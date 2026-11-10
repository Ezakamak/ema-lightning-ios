export const MAX_BYTES=1048576;
export function key(word) {
 const n=word.normalize('NFC');
 return /[çğıöşüÇĞÖŞÜ]/u.test(n)?n.toLocaleLowerCase('tr-TR'):n.replaceAll('İ','I').toLocaleLowerCase('en-US');
}
export function validate(rules) {
 if(!Array.isArray(rules)||!rules.length||rules.length>5000) throw Error('Invalid count');
 const seen=new Set();
 return rules.map(r=>{
  if(typeof r.word!=='string'||typeof r.pronunciation!=='string'||typeof r.category!=='string') throw Error('Invalid fields');
  const word=r.word.normalize('NFC').trim().replace(/\s+/gu,' '), pronunciation=r.pronunciation.normalize('NFC').trim().replace(/\s+/gu,' ');
  if(!word||[...word].length>64||!/\p{L}/u.test(word)||!/^[\p{L}\p{N} .+#&’'/_-]+$/u.test(word)||[...pronunciation].length>128||!/^[A-Za-zÇĞİÖŞÜçğıöşü]+(?:[ ’'\-][A-Za-zÇĞİÖŞÜçğıöşü]+)*$/u.test(pronunciation)||!r.category||r.category.length>80) throw Error('Invalid rule');
  if(seen.has(key(word))) throw Error('Duplicate'); seen.add(key(word));
  return {word,pronunciation,category:r.category.normalize('NFC')};
 }).sort((a,b)=>key(a.word)<key(b.word)?-1:1);
}
export function canonical(rules) {
 const hex=s=>[...new TextEncoder().encode(s)].map(b=>b.toString(16).padStart(2,'0')).join('');
 return rules.map(r=>[key(r.word),r.word,r.pronunciation,r.category].map(hex).join(':')).sort().join('\n');
}
export async function checksum(rules) {
 return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(canonical(rules))))].map(b=>b.toString(16).padStart(2,'0')).join('');
}
