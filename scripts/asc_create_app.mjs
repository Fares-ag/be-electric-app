#!/usr/bin/env node
/**
 * Create (or verify) an App Store Connect app record via API.
 *
 * Requires scripts/asc.env (see asc.env.example):
 *   ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH
 *
 * Usage:
 *   node scripts/asc_create_app.mjs \
 *     --bundle-id com.beelectric.cmms.technicianCmms \
 *     --name "Be Electric Tech" \
 *     --sku beelectric-technician-cmms
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createAscJwt } from './lib/asc_jwt.mjs';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  for (const line of fs.readFileSync(filePath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = value;
  }
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

async function ascFetch(token, pathname, { method = 'GET', body } = {}) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${pathname}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!response.ok) {
    const detail =
      json?.errors?.map((e) => `${e.title}: ${e.detail}`).join('; ') ||
      json.raw ||
      response.statusText;
    throw new Error(`${method} ${pathname} failed (${response.status}): ${detail}`);
  }
  return json;
}

async function main() {
  loadEnvFile(path.join(scriptDir, 'asc.env'));

  const args = parseArgs(process.argv.slice(2));
  const bundleId = args['bundle-id'];
  const name = args.name;
  const sku = args.sku;
  const locale = args.locale || 'en-US';

  if (!bundleId || !name || !sku) {
    console.error(
      'Usage: node scripts/asc_create_app.mjs --bundle-id <id> --name <name> --sku <sku>',
    );
    process.exit(1);
  }

  const keyId = process.env.ASC_KEY_ID;
  const issuerId = process.env.ASC_ISSUER_ID;
  const privateKeyPath = process.env.ASC_PRIVATE_KEY_PATH;

  if (!keyId || !issuerId || !privateKeyPath) {
    console.error('Missing ASC credentials. Create scripts/asc.env from asc.env.example.');
    process.exit(1);
  }
  if (!fs.existsSync(privateKeyPath)) {
    console.error(`ASC private key not found: ${privateKeyPath}`);
    process.exit(1);
  }

  const token = createAscJwt({ keyId, issuerId, privateKeyPath });
  const existing = await ascFetch(
    token,
    `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}&limit=1`,
  );
  if (existing.data?.length) {
    const app = existing.data[0];
    console.log(`OK: App already exists (${app.id}) — ${bundleId}`);
    return;
  }

  const created = await ascFetch(token, '/v1/apps', {
    method: 'POST',
    body: {
      data: {
        type: 'apps',
        attributes: {
          bundleId,
          name,
          sku,
          primaryLocale: locale,
        },
      },
    },
  });

  console.log(`OK: Created App Store Connect app (${created.data.id}) — ${bundleId}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
