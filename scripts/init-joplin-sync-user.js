// Run inside a fresh official Joplin container; stdout is secret, redirect it.
const fs = require('node:fs');
const http = require('node:http');
const crypto = require('node:crypto');
const serverRequire = require('node:module').createRequire('/home/joplin/packages/server/dist/app.js');
const { Client } = serverRequire('pg');
const admin = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const base = new URL(process.env.APP_BASE_URL);
let token = '';
function api(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : '';
    const req = http.request({ hostname: '127.0.0.1', port: 22300, method, path,
      headers: { Host: base.host, 'X-Forwarded-Host': base.host, 'X-Forwarded-Proto': 'https',
        'X-API-AUTH': token, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } }, (res) => {
      let text = ''; res.on('data', chunk => { text += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 400) return reject(new Error(`API returned ${res.statusCode}`));
        try { resolve(text ? JSON.parse(text) : null); } catch { reject(new Error('Invalid API response')); }
      });
    });
    req.on('error', reject); req.setTimeout(15000, () => req.destroy(new Error('API timeout'))); req.end(data);
  });
}
(async () => {
  token = (await api('POST', '/api/sessions', admin)).id;
  const email = `sync@${base.hostname}`;
  const users = await api('GET', '/api/users');
  if (users.items.some(user => user.email === email)) throw new Error('Refusing to overwrite an existing sync user');
  const user = await api('POST', '/api/users', { email, full_name: 'Personal sync', is_admin: 0, can_upload: 1 });
  const password = crypto.randomBytes(30).toString('base64url');
  await api('PATCH', `/api/users/${user.id}`, { password, must_set_password: 0, can_upload: 1 });
  const db = new Client({ host: process.env.POSTGRES_HOST, port: Number(process.env.POSTGRES_PORT),
    database: process.env.POSTGRES_DATABASE, user: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD });
  await db.connect();
  try { await db.query('UPDATE users SET email_confirmed=1 WHERE id=$1 AND is_admin=0', [user.id]); }
  finally { await db.end(); }
  const verified = await api('POST', '/api/sessions', { email, password });
  if (!verified.id) throw new Error('Sync login verification failed');
  process.stdout.write(JSON.stringify({ server: base.origin, email, password }, null, 2));
})().catch(error => { console.error(`Sync user bootstrap failed: ${error.message}`); process.exit(1); });
