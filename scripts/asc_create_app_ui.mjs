#!/usr/bin/env node
/**
 * Create technician App Store Connect app via UI automation.
 * Run: node scripts/asc_create_app_ui.mjs
 */
import { chromium } from 'playwright';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));

const CONFIG = {
  appsUrl: 'https://appstoreconnect.apple.com/apps',
  name: 'Be Electric Tech',
  bundleId: 'com.beelectric.cmms.technicianCmms',
  sku: 'beelectric-technician-cmms',
  profileDir: path.join(process.env.HOME, '.beelectric-asc-profile'),
  screenshotDir: path.join(scriptDir, '.asc-ui-screenshots'),
};

async function waitForSignedIn(page) {
  console.log('Waiting for App Store Connect (sign in + 2FA in browser if needed)...');
  const deadline = Date.now() + 5 * 60 * 1000;
  while (Date.now() < deadline) {
    const url = page.url();
    if (url.includes('authResult=FAILED')) {
      await page.waitForTimeout(2000);
      continue;
    }
    if (
      url.includes('appstoreconnect.apple.com') &&
      !url.includes('idmsa.apple.com') &&
      !url.includes('appleid.apple.com')
    ) {
      return;
    }
    await page.waitForTimeout(1500);
  }
  throw new Error('Timed out waiting for App Store Connect login.');
}

async function openNewAppDialog(page) {
  await page.goto(CONFIG.appsUrl, { waitUntil: 'domcontentloaded' });
  await waitForSignedIn(page);
  await page.waitForLoadState('networkidle', { timeout: 90000 }).catch(() => {});
  await page.waitForTimeout(3000);

  // Already on new app form?
  if (page.url().includes('/apps/new')) return;

  console.log('Opening New App dialog...');
  const addButton = page.locator('button, a, [role=button]').filter({ hasText: /^\+$/ }).first();
  if (await addButton.count()) {
    await addButton.click();
  } else {
    await page.locator('[aria-label*="Add" i], [title*="Add" i]').first().click({ timeout: 15000 });
  }

  await page.getByRole('menuitem', { name: /New App/i }).click({ timeout: 15000 }).catch(async () => {
    await page.getByText(/^New App$/).click({ timeout: 10000 });
  });

  await page.getByRole('dialog').waitFor({ state: 'visible', timeout: 20000 });
}

async function fillNewAppDialog(page) {
  console.log('Filling New App form...');
  const dialog = page.getByRole('dialog');

  // iOS platform checkbox in dialog
  const iosLabel = dialog.getByText(/^iOS$/).first();
  await iosLabel.click({ timeout: 15000 });

  // Name
  await dialog.getByLabel(/^Name$/i).fill(CONFIG.name);

  // Primary language (first select in dialog)
  const langSelect = dialog.locator('select').first();
  await langSelect.selectOption({ label: 'English (U.S.)' }).catch(() =>
    langSelect.selectOption('en-US'),
  );

  // Bundle ID (select containing our bundle id)
  const bundleSelect = dialog.locator('select').filter({
    has: page.locator(`option[value="${CONFIG.bundleId}"]`),
  }).first();
  if (await bundleSelect.count()) {
    await bundleSelect.selectOption(CONFIG.bundleId);
  } else {
    await dialog.locator('select').nth(1).selectOption(CONFIG.bundleId).catch(async () => {
      await dialog.locator('select').nth(1).selectOption({ label: CONFIG.bundleId });
    });
  }

  // SKU
  await dialog.getByLabel(/^SKU$/i).fill(CONFIG.sku);

  // Full Access
  await dialog.getByText(/Full Access/i).click();

  await dialog.getByRole('button', { name: /^Create$/i }).click();
}

async function main() {
  const browser = await chromium.launchPersistentContext(CONFIG.profileDir, {
    headless: false,
    viewport: { width: 1400, height: 900 },
    slowMo: 80,
  });
  const page = browser.pages()[0] || (await browser.newPage());

  try {
    await openNewAppDialog(page);
    await fillNewAppDialog(page);
    console.log('Clicked Create — waiting for app record...');
    await page.waitForURL(/\/apps\/\d+/, { timeout: 120000 });
    console.log(`OK: App created — ${page.url()}`);
  } catch (err) {
    await page.screenshot({
      path: path.join(CONFIG.screenshotDir, `error-${Date.now()}.png`),
      fullPage: true,
    }).catch(() => {});
    throw err;
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
