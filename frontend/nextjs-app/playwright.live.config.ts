import { defineConfig, devices } from '@playwright/test';

// Explicit opt-in: default CI and local suites must never target production.
if (process.env.MYAAPTHA_LIVE_TESTS !== '1') throw new Error('Set MYAAPTHA_LIVE_TESTS=1 for the bounded read-only live checks');
export default defineConfig({
  testDir: './live-tests', outputDir: '../../.tools/live-beta-20261114', workers: 1, retries: 0,
  reporter: 'list', timeout: 120_000,
  use: { baseURL: 'https://35-244-31-192.sslip.io', trace: 'retain-on-failure', launchOptions: { timeout: 30_000 } },
  projects: [
    { name: 'desktop-live', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile-live', use: { ...devices['Pixel 7'] } },
  ],
});
