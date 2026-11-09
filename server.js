import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const base=path.dirname(fileURLToPath(import.meta.url));
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml'};
const server=http.createServer(async(req,res)=>{try{const url=new URL(req.url,'http://localhost');let file=decodeURIComponent(url.pathname);if(file==='/')file='/index.html';const target=path.resolve(base,'.'+file);if(!target.startsWith(base+path.sep)&&target!==base)throw new Error('invalid path');const info=await stat(target);if(!info.isFile())throw new Error('not a file');res.writeHead(200,{'content-type':types[path.extname(target)]||'application/octet-stream','cache-control':'no-store'});res.end(await readFile(target));}catch{res.writeHead(404,{'content-type':'text/plain; charset=utf-8'});res.end('not found');}});
const port=Number(process.env.PORT||4173);server.listen(port,'0.0.0.0',()=>console.log(`AOT static site ready on http://localhost:${port}`));
