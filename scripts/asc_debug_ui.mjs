#!/usr/bin/env node
import { chromium } from 'playwright';
import path from 'node:path';

const profileDir = path.join(process.env.HOME, '.beelectric-asc-profile');

const browser = await chromium.launchPersistentContext(profileDir, {
  headless: false,
  viewport: { width: 1400, height: 900 },
});
const page = browser.pages()[0] || (await browser.newPage());
await page.goto('https://appstoreconnect.apple.com/apps', { waitUntil: 'networkidle' });
await page.waitForTimeout(5000);

const buttons = await page.locator('button, a, [role=button]').evaluateAll((els) =>
  els.slice(0, 40).map((el) => ({
    tag: el.tagName,
    text: (el.textContent || '').trim().slice(0, 80),
    aria: el.getAttribute('aria-label'),
    title: el.getAttribute('title'),
    cls: (el.className || '').toString().slice(0, 80),
  })),
);

console.log(JSON.stringify(buttons, null, 2));
await page.screenshot({ path: 'scripts/.asc-ui-screenshots/debug-apps.png', fullPage: true });
await browser.close();
