const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const WEB_DIR = path.join(__dirname, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];

  // Normalize kapookluxx prefix
  if (reqPath.startsWith('/kapookluxx')) {
    reqPath = reqPath.slice('/kapookluxx'.length);
  }

  if (reqPath === '' || reqPath === '/') {
    reqPath = '/index.html';
  }

  let filePath = path.join(WEB_DIR, decodeURIComponent(reqPath));

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Fallback for SPA routing
      filePath = path.join(WEB_DIR, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
      if (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Server Error: ' + err.code);
      } else {
        res.writeHead(200, {
          'Content-Type': contentType,
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-cache',
        });
        res.end(content);
      }
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Kapookluxx Mobile Live Server is running!`);
  console.log(`📱 Localhost URL: http://localhost:${PORT}/kapookluxx/`);
  console.log(`📶 WiFi Network (Mobile Device) URL: http://10.56.142.100:${PORT}/kapookluxx/`);
});
