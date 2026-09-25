// Minimal static file server for the built single-page app.
//
// Azure App Service on Linux needs a process listening on $PORT; it will not
// serve a folder on its own. This uses Node built-ins only, so the deployment
// package is just the build output plus this file — no install step on the
// server, no dependency surface, nothing extra to keep patched.

import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)));
const PORT = Number(process.env.PORT) || 8080;

const MIME = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

// Vite fingerprints everything under /assets/, so those URLs can never go stale
// and are safe to cache forever. index.html must never be cached, or a browser
// keeps requesting the previous build's asset names after a deploy.
function cacheControl(pathname) {
  return pathname.startsWith('/assets/') ? 'public, max-age=31536000, immutable' : 'no-cache';
}

function securityHeaders() {
  return {
    'Content-Security-Policy':
      "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'",
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  };
}

// Resolve a URL path to a file inside ROOT, or null if it would escape it.
function resolveWithinRoot(pathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  if (decoded.includes('\0')) return null;
  const candidate = resolve(join(ROOT, normalize(decoded)));
  if (candidate !== ROOT && !candidate.startsWith(ROOT + sep)) return null;
  return candidate;
}

async function fileOrNull(path) {
  try {
    const info = await stat(path);
    return info.isFile() ? info : null;
  } catch {
    return null;
  }
}

const server = createServer(async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD', ...securityHeaders() }).end();
    return;
  }

  const { pathname } = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);

  if (pathname === '/healthz') {
    res
      .writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
      .end(JSON.stringify({ status: 'ok' }));
    return;
  }

  let target = resolveWithinRoot(pathname === '/' ? '/index.html' : pathname);
  if (!target) {
    res.writeHead(400, securityHeaders()).end('Bad request');
    return;
  }

  let info = await fileOrNull(target);

  // Single-page app fallback: anything that is not a real file is treated as a
  // client route. Requests under /assets/ are excluded, because a missing asset
  // is a genuine 404 and answering it with HTML produces a confusing MIME-type
  // error in the browser rather than an obvious missing-file error.
  if (!info && !pathname.startsWith('/assets/')) {
    target = join(ROOT, 'index.html');
    info = await fileOrNull(target);
  }

  if (!info) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', ...securityHeaders() });
    res.end('Not found');
    return;
  }

  res.writeHead(200, {
    'Cache-Control': cacheControl(pathname),
    'Content-Length': info.size,
    'Content-Type': MIME[extname(target).toLowerCase()] ?? 'application/octet-stream',
    ...securityHeaders(),
  });

  if (req.method === 'HEAD') {
    res.end();
    return;
  }

  createReadStream(target).pipe(res);
});

server.listen(PORT, () => {
  console.log(`dicom-squeeze listening on ${PORT}, serving ${ROOT}`);
});
