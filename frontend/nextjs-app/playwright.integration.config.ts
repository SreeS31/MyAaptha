import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './integration',
  outputDir: './test-results/integration',
  workers: 1,
  timeout: 180_000,
  use: { baseURL: 'http://localhost:3000' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile-web', use: { ...devices['Pixel 7'] } },
  ],
});
