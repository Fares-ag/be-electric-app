#!/usr/bin/env node
/**
 * Direct Postgres CLI — no psql/Homebrew required.
 * Uses the `postgres` npm package (TCP to Supabase).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import postgres from 'postgres';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const scriptsDir = path.resolve(__dirname, '..');
const envFile = path.join(scriptsDir, 'db.env');

function loadEnvFile() {
  if (!fs.existsSync(envFile)) return;
  const text = fs.readFileSync(envFile, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
}

function buildDatabaseUrl() {
  if (process.env.DATABASE_URL?.trim()) {
    return process.env.DATABASE_URL.trim();
  }
  const password = process.env.SUPABASE_DB_PASSWORD?.trim();
  if (!password) return null;

  let ref = process.env.SUPABASE_PROJECT_REF?.trim() || '';
  const supabaseUrl = process.env.SUPABASE_URL?.trim() || '';
  if (!ref && supabaseUrl) {
    ref = supabaseUrl.replace(/^https?:\/\//, '').replace(/\.supabase\.co.*/, '');
  }

  const host =
    process.env.SUPABASE_DB_HOST?.trim() ||
    (ref ? `db.${ref}.supabase.co` : '');
  const port = process.env.SUPABASE_DB_PORT?.trim() || '5432';
  const user = process.env.SUPABASE_DB_USER?.trim() || 'postgres';
  const db = process.env.SUPABASE_DB_NAME?.trim() || 'postgres';

  if (!host) return null;
  return `postgresql://${user}:${encodeURIComponent(password)}@${host}:${port}/${db}`;
}

loadEnvFile();
const databaseUrl = buildDatabaseUrl();

const PRESETS = {
  tables: `
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name`,
  users: `
    SELECT id, email, name, role, companyId, isActive
    FROM users ORDER BY email LIMIT 50`,
  'work-orders': `
    SELECT id, ticketNumber, status, requestorId, companyId, createdAt
    FROM work_orders ORDER BY createdAt DESC LIMIT 25`,
  assets: `
    SELECT id, name, manufacturer, companyId, location, status
    FROM assets ORDER BY name LIMIT 50`,
  companies: `
    SELECT id, name, createdAt FROM companies ORDER BY name LIMIT 50`,
};

function printRows(rows) {
  if (!rows?.length) {
    console.log('(no rows)');
    return;
  }
  console.table(rows);
}

async function main() {
  const [cmd, arg] = process.argv.slice(2);

  if (!cmd || cmd === 'help' || cmd === '-h' || cmd === '--help') {
    console.log(`
Be Electric DB CLI (Node — no psql required)

  node db.mjs check
  node db.mjs query "SELECT count(*) FROM work_orders"
  node db.mjs run ../sql/app_review_checklist.sql
  node db.mjs tables | users | work-orders | assets | companies

Configure: scripts/db.env (copy from db.env.example)
`);
    return;
  }

  if (!databaseUrl) {
    console.error('Missing DATABASE_URL or SUPABASE_DB_PASSWORD in scripts/db.env');
    process.exit(1);
  }

  const sql = postgres(databaseUrl, {
    ssl: 'require',
    max: 1,
    connect_timeout: 15,
  });

  try {
    switch (cmd) {
      case 'check':
        const check = await sql`
          SELECT current_database() AS db,
                 current_user AS user,
                 now() AS server_time`;
        console.table(check);
        console.log('Connection OK.');
        break;

      case 'query':
      case 'q':
        if (!arg) {
          console.error('Usage: node db.mjs query "SELECT ..."');
          process.exit(1);
        }
        printRows(await sql.unsafe(arg));
        break;

      case 'run':
      case 'file':
      case 'f':
        const filePath = arg
          ? path.resolve(process.cwd(), arg)
          : null;
        if (!filePath || !fs.existsSync(filePath)) {
          console.error('Usage: node db.mjs run path/to/file.sql');
          process.exit(1);
        }
        const fileSql = fs.readFileSync(filePath, 'utf8');
        const runAsSingleScript =
          /^\s*BEGIN\s*;/im.test(fileSql) ||
          /\bDO\s+\$\$/im.test(fileSql) ||
          filePath.includes('migrate_');

        if (runAsSingleScript) {
          await sql.unsafe(fileSql);
          console.log('Script completed.');
          break;
        }

        // Run multiple statements (split on ; at line end) for checklist files
        const statements = fileSql
          .split(/;\s*\n/)
          .map((s) => s.trim())
          .filter((s) => s && !s.startsWith('--'));
        for (const stmt of statements) {
          if (!stmt) continue;
          console.log('---');
          console.log(stmt.split('\n')[0].slice(0, 80) + '...');
          printRows(await sql.unsafe(stmt));
        }
        break;

      default:
        if (PRESETS[cmd]) {
          printRows(await sql.unsafe(PRESETS[cmd]));
        } else {
          console.error(`Unknown command: ${cmd}`);
          process.exit(1);
        }
    }
  } catch (e) {
    console.error('Error:', e.message || e);
    process.exit(1);
  } finally {
    await sql.end({ timeout: 2 });
  }
}

main();
