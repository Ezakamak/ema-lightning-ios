export async function serveV2(request,env) {
 const path=new URL(request.url).pathname;
 const match=path.match(/^\/api\/v2\/pronunciations\/(manifest|chunks\/([a-f0-9]{64}))$/);
 if(!match) return new Response(null,{status:404});
 try {
  const row=match[1]==='manifest'
   ? await env.DB.prepare("SELECT r.manifest AS payload FROM dictionary_channels c JOIN dictionary_releases r ON r.version=c.version WHERE c.channel='stable'").first()
   : await env.DB.prepare('SELECT payload FROM dictionary_chunks WHERE hash=?').bind(match[2]).first();
  if(!row) return new Response(null,{status:match[2]?404:503});
  const bytes=new TextEncoder().encode(row.payload);
  if(bytes.length>262144) throw Error('oversized');
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
  if(match[2]&&digest!==match[2]) throw Error('corrupt');
  const etag=`"${digest}"`,headers={'Content-Type':'application/json; charset=utf-8',ETag:etag,'X-Content-Type-Options':'nosniff','Cache-Control':match[2]?'public, max-age=31536000, immutable':'no-cache'};
  if(request.headers.get('if-none-match')===etag) return new Response(null,{status:304,headers});
  return new Response(request.method==='HEAD'?null:row.payload,{headers});
 } catch {return Response.json({error:'dictionary_unavailable'},{status:503});}
}
