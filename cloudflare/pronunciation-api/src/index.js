import {serveV2} from './v2.js';
import {MAX_BYTES} from './dictionary.js';
function json(body,status=200,extra={}) {return new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...extra}});}
export default {async fetch(request,env,ctx) {
 const url=new URL(request.url),path=url.pathname;
 if(!['GET','HEAD','OPTIONS'].includes(request.method)) return json({error:'method_not_allowed'},405,{Allow:'GET, HEAD, OPTIONS'});
 if(url.search||Number(request.headers.get('content-length')||0)>0) return json({error:'unexpected_payload'},400);
 if(!path.startsWith('/api/v2/pronunciations/')&&!['/api/v1/health','/api/v1/pronunciations','/api/v1/pronunciations/version'].includes(path)) return json({error:'not_found'},404);
 if(request.headers.get('origin')&&request.headers.get('origin')!=='https://speak.ekatech.net') return json({error:'origin_not_allowed'},403);
 const headers={'Access-Control-Allow-Origin':'https://speak.ekatech.net','Access-Control-Expose-Headers':'ETag','Cache-Control':'public, max-age=300','Vary':'Origin'};
 if(request.method==='OPTIONS') return new Response(null,{status:204,headers:{...headers,'Access-Control-Allow-Methods':'GET, HEAD, OPTIONS','Access-Control-Allow-Headers':'If-None-Match'}});
 const limiter=path.startsWith('/api/v2/')?env.V2_RATE_LIMITER:env.RATE_LIMITER;
 if(limiter&&!(await limiter.limit({key:request.headers.get('cf-connecting-ip')||'unknown'})).success) return json({error:'rate_limited'},429,{'Retry-After':'60'});
 if(path.startsWith('/api/v2/pronunciations/')) return serveV2(request,env);
 if(path==='/api/v1/health') return request.method==='HEAD'?new Response(null,{headers}):json({status:'ok'},200,headers);
 try {
  const cache=globalThis.caches?.default,cacheKey=new Request(url.origin+path);
  let response=await cache?.match(cacheKey);
  if(!response) {
   const row=await env.DB.prepare('SELECT version,updated_at,payload FROM dictionary_metadata ORDER BY version DESC LIMIT 1').first();
   if(!row) return json({error:'dictionary_unavailable'},503,{'Retry-After':'300'});
   const s={...JSON.parse(row.payload),version:row.version,updatedAt:row.updated_at};
   if(s.schemaVersion!==1||s.rules.length!==s.ruleCount||!s.ruleCount) throw Error('Invalid snapshot');
   const body=JSON.stringify(path.endsWith('/version')?{version:s.version,schemaVersion:1,locale:s.locale,ruleCount:s.ruleCount,updatedAt:s.updatedAt,checksum:s.checksum}:s);
   if(new TextEncoder().encode(body).length>MAX_BYTES) throw Error('Snapshot too large');
   response=new Response(body,{headers:{...headers,'Content-Type':'application/json; charset=utf-8','X-Content-Type-Options':'nosniff',ETag:`"ema-${s.version}-${s.checksum}-${path.endsWith('/version')?'meta':'full'}"`}});
   if(cache) ctx.waitUntil(cache.put(cacheKey,response.clone()));
  }
  const etag=response.headers.get('etag');
  const clientHeaders=new Headers(response.headers);
  clientHeaders.set('Cache-Control','no-cache');
  clientHeaders.set('Cloudflare-CDN-Cache-Control','no-store');
  if((request.headers.get('if-none-match')||'').split(',').some(t=>t.trim()==='*'||t.trim().replace(/^W\//,'')===etag)) return new Response(null,{status:304,headers:clientHeaders});
  return new Response(request.method==='HEAD'?null:response.body,{headers:clientHeaders});
 } catch {return json({error:'dictionary_unavailable'},503,{'Retry-After':'300'});}
}};
