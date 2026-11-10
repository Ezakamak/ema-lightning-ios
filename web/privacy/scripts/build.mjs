import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
const root=new URL('../',import.meta.url); const assets={};
for(const name of await readdir(new URL('site/',root))){const data=await readFile(new URL('site/'+name,root));assets['/'+name]={body:data.toString('base64'),type:({html:'text/html; charset=utf-8',css:'text/css; charset=utf-8',js:'text/javascript; charset=utf-8',svg:'image/svg+xml',xml:'application/xml',txt:'text/plain; charset=utf-8'})[name.split('.').pop()]};}
await mkdir(new URL('dist/',root),{recursive:true});
await writeFile(new URL('dist/worker.mjs',root),'const assets='+JSON.stringify(assets)+';\n'+await readFile(new URL('src/handler.mjs',root),'utf8'));
console.log('Built '+Object.keys(assets).length+' local assets');
