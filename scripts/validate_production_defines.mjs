#!/usr/bin/env node
/**
 * Validates scripts/defines.production.json before release builds.
 * Usage: node scripts/validate_production_defines.mjs [path-to-json]
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const definesPath = resolve(process.argv[2] ?? `${scriptDir}/defines.production.json`);

const requiredKeys = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'PRIVACY_POLICY_URL',
  'TERMS_OF_SERVICE_URL',
  'SUPPORT_URL',
  'SUPPORT_EMAIL',
  'ENABLE_PM_OCCURRENCES',
];

const placeholderPatterns = [
  /your-project\.supabase\.co/i,
  /your-supabase-anon-key/i,
  /your-domain\.com/i,
  /your_anon_key/i,
  /YOUR_/,
];

if (!existsSync(definesPath)) {
  console.error(`ERROR: Missing ${definesPath}`);
  console.error('Run: ./scripts/setup_production_defines.sh');
  process.exit(1);
}

let defines;
try {
  defines = JSON.parse(readFileSync(definesPath, 'utf8'));
} catch (error) {
  console.error(`ERROR: Invalid JSON in ${definesPath}: ${error.message}`);
  process.exit(1);
}

const errors = [];

for (const key of requiredKeys) {
  const value = String(defines[key] ?? '').trim();
  if (!value) {
    errors.push(`Missing or empty: ${key}`);
    continue;
  }
  for (const pattern of placeholderPatterns) {
    if (pattern.test(value)) {
      errors.push(`${key} still contains a placeholder value`);
      break;
    }
  }
}

if (defines.SUPABASE_URL && !String(defines.SUPABASE_URL).startsWith('https://')) {
  errors.push('SUPABASE_URL must start with https://');
}

if (defines.SUPPORT_EMAIL && !String(defines.SUPPORT_EMAIL).includes('@')) {
  errors.push('SUPPORT_EMAIL must look like an email address');
}

const pmFlag = String(defines.ENABLE_PM_OCCURRENCES ?? '').trim().toLowerCase();
if (pmFlag !== 'true' && pmFlag !== 'false') {
  errors.push('ENABLE_PM_OCCURRENCES must be "true" or "false"');
}

if (errors.length > 0) {
  console.error('Production defines validation failed:');
  for (const message of errors) {
    console.error(`  - ${message}`);
  }
  console.error(`\nEdit ${definesPath} with real production values.`);
  process.exit(1);
}

console.log(`OK: ${definesPath} has required release dart-defines.`);
if (pmFlag === 'true') {
  console.log('  ENABLE_PM_OCCURRENCES=true — unified PM inbox + requestor read-only PM enabled.');
} else {
  console.log('  ENABLE_PM_OCCURRENCES=false — legacy pm_tasks only (requestor PM module hidden).');
}
