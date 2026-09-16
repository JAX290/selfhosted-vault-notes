// Bootstrap ONLY a fresh Joplin Server. Run inside the official server container.
// Stdout contains generated credentials: redirect it to an ignored, restricted file.
const crypto = require('node:crypto');
const serverRequire = require('node:module').createRequire('/home/joplin/packages/server/dist/app.js');
const { Client } = serverRequire('pg');
const { hashPassword, checkPassword } = require('/home/joplin/packages/server/dist/utils/auth');

(async () => {
  const db = new Client({
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    database: process.env.POSTGRES_DATABASE,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });
  await db.connect();
  try {
    const rows = (await db.query('SELECT id,password FROM users WHERE email=$1 AND is_admin=1', ['admin@localhost'])).rows;
    if (rows.length !== 1 || !(await checkPassword('admin', rows[0].password))) {
      throw new Error('Refusing to modify an administrator that no longer has the default password');
    }
    const password = crypto.randomBytes(30).toString('base64url');
    const hash = await hashPassword(password);
    await db.query('UPDATE users SET password=$1,updated_time=$2 WHERE id=$3', [hash, Date.now(), rows[0].id]);
    process.stdout.write(JSON.stringify({ email: 'admin@localhost', password }, null, 2));
  } finally {
    await db.end();
  }
})().catch(() => { console.error('Fresh administrator bootstrap failed; credentials not printed'); process.exit(1); });
