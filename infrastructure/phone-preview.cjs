// Local Wi-Fi Android preview. No directory listings or arbitrary file serving.
const http = require('node:http');
const net = require('node:net');
const fs = require('node:fs');
const path = require('node:path');
const host = process.argv[2];
const port = Number(process.argv[3] || 4320);
if (!/^192\.168\.\d{1,3}\.\d{1,3}$/.test(host || '') && !/^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host || '')) throw Error('Specify a private LAN IPv4 address.');
const apk = path.resolve(__dirname, '../.tools/phone-preview/myaaptha-android.apk');
const apkIdentity = path.resolve(__dirname, '../.tools/phone-preview/apk-identity.json');
function readyApk() {
  try {
    const identity = JSON.parse(fs.readFileSync(apkIdentity, 'utf8').replace(/^\uFEFF/, ''));
    return identity.apiBaseUrl === `http://${host}:${port}` && identity.downloadMatchesBuild === true &&
      identity.sizeBytes === fs.statSync(apk).size;
  } catch { return false; }
}
const server = http.createServer((req, res) => {
  if (req.url === '/' && req.method === 'GET') {
    const body = '<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>MyAaptha mobile preview</title><style>body{font:18px system-ui;max-width:560px;margin:48px auto;padding:24px;color:#163440}a{display:block;background:#216f7d;color:white;padding:18px;border-radius:14px;margin:20px 0}</style><h1>MyAaptha for Android</h1><p>Local testing build. Keep your phone and computer on the same trusted Wi-Fi, with the computer running.</p><a href="/downloads/myaaptha-android.apk">Download Android app (APK)</a><a href="/api/auth/health">Check API connection</a><p>Install the downloaded APK, then sign in with your MyAaptha account. This is a development build, not an app-store release.</p>';
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}); res.end(body); return;
  }
  if (req.url === '/downloads/myaaptha-android.apk' && ['GET','HEAD'].includes(req.method)) {
    if (!readyApk()) { res.writeHead(503, {'Cache-Control':'no-store','Retry-After':'30'}); res.end('A verified build for this network address is being prepared.'); return; }
    res.writeHead(200, {'Content-Type':'application/vnd.android.package-archive','Content-Length':fs.statSync(apk).size,'Content-Disposition':'attachment; filename="myaaptha-android.apk"','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
    if(req.method === 'HEAD') res.end(); else fs.createReadStream(apk).pipe(res); return;
  }
  if (!req.url.startsWith('/api/')) { res.writeHead(404); res.end(); return; }
  const upstream = http.request({hostname:'127.0.0.1',port:8080,path:req.url,method:req.method,headers:{...req.headers,host:'127.0.0.1:8080'}}, response => {
    res.writeHead(response.statusCode, response.headers); response.pipe(res);
  });
  upstream.on('error', () => { if(!res.headersSent) res.writeHead(502); res.end('Local API unavailable.'); });
  req.pipe(upstream);
});
server.on('upgrade', (req, socket, head) => {
  if (!req.url.startsWith('/api/')) { socket.destroy(); return; }
  const upstream = net.connect(8080,'127.0.0.1', () => {
    upstream.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n` + Object.entries({...req.headers,host:'127.0.0.1:8080'}).map(([k,v])=>`${k}: ${v}`).join('\r\n')+'\r\n\r\n');
    if(head.length) upstream.write(head);
    upstream.pipe(socket); socket.pipe(upstream);
  });
  upstream.on('error',()=>socket.destroy()); socket.on('error',()=>upstream.destroy()); socket.on('close',()=>upstream.destroy());
});
server.listen(port, host, () => console.log(`Phone preview: http://${host}:${port}`));
