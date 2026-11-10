import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker from '../dist/worker.mjs';
const request=(path,options)=>worker.fetch(new Request('https://speak.ekatech.net'+path,options));
test('policy is directly available in both languages without cookies or client rendering',async()=>{
 for(const [p,lang,words] of [['/privacy','tr','Saklama ve silme'],['/en/privacy','en','Retention and deletion']]){
  const r=request(p);assert.equal(r.status,200);assert.equal(r.headers.get('set-cookie'),null);
  const html=await r.text();assert.match(html,new RegExp('lang="'+lang+'"'));assert.ok(html.includes(words));assert.ok(html.includes('contact@ekatech.net'));assert.ok(html.includes('127.0.0.1'));assert.ok(!html.includes('casino'));
 }
});
test('HTTPS, host restriction, methods and HEAD',async()=>{
 assert.equal(worker.fetch(new Request('http://speak.ekatech.net/privacy')).status,308);
 assert.equal(worker.fetch(new Request('https://casino.ekatech.net/privacy')).status,404);
 assert.equal(request('/privacy',{method:'POST',body:'test'}).status,405);
 const r=request('/privacy',{method:'HEAD'});assert.equal(r.status,200);assert.equal(await r.text(),'');
});
test('home and assets accessible; API routes are never served as policy pages',async()=>{
 for(const p of ['/','/en','/style.css','/preferences.js','/og.svg','/robots.txt','/sitemap.xml'])assert.equal(request(p).status,200);
 assert.equal(request('/api/v1/health').status,404);
 assert.equal(request('/nonexistent').status,404);
 assert.match(request('/privacy').headers.get('content-security-policy'),/connect-src 'none'/);
});
