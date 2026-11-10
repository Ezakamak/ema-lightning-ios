const headers={
 'Content-Security-Policy':"default-src 'none'; style-src 'self'; script-src 'self'; img-src 'self'; connect-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
 'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Permissions-Policy':'camera=(), microphone=(), geolocation=()',
 'Strict-Transport-Security':'max-age=31536000','Cache-Control':'public, max-age=0, must-revalidate'
};
export default {fetch(request){
 const url=new URL(request.url);
 if(url.hostname!=='speak.ekatech.net')return new Response('Not found',{status:404});
 if(url.protocol!=='https:'){url.protocol='https:';return Response.redirect(url.href,308);}
 if(!['GET','HEAD'].includes(request.method))return new Response('Method not allowed',{status:405,headers:{...headers,Allow:'GET, HEAD'}});
 const names={'/':'/index.html','/privacy':'/privacy.html','/privacy/':'/privacy.html','/en':'/en.html','/en/':'/en.html','/en/privacy':'/privacy-en.html','/en/privacy/':'/privacy-en.html'};
 const asset=assets[names[url.pathname]||url.pathname];
 if(!asset)return new Response('Not found',{status:404,headers});
 const bytes=Uint8Array.from(atob(asset.body),c=>c.charCodeAt(0));
 return new Response(request.method==='HEAD'?null:bytes,{headers:{...headers,'Content-Type':asset.type}});
}};
