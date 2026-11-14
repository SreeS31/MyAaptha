import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { writeFileSync } from 'node:fs';

test('public beta screens: navigation, accessibility, viewport and browser errors', async ({ page }, info) => {
  const errors: string[] = [];
  const measurements: unknown[] = [];
  page.on('pageerror', error => errors.push(error.message));
  for (const path of ['/', '/auth', '/recover-account', '/verify-phone']) {
    const response = await page.goto(path);
    expect(response?.status(), path).toBe(200);
    await expect(page.locator('main')).toBeVisible();
    await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
    await page.evaluate(() => document.fonts.ready);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1), path).toBe(true);
    const accessibility = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
    measurements.push({ path, accessibility: accessibility.violations.map(v => ({ id: v.id, impact: v.impact, targets: v.nodes.map(n => n.target) })),
      navigation: await page.evaluate(() => {
        const entry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
        return { ttfbMs: Math.round(entry.responseStart - entry.requestStart), domReadyMs: Math.round(entry.domContentLoadedEventEnd - entry.startTime), transferBytes: entry.transferSize };
      }),
    });
    await page.screenshot({ path: info.outputPath(`${path.replaceAll('/', '') || 'home'}.png`), fullPage: true });
    expect.soft(accessibility.violations, path).toEqual([]);
  }
  await page.goto('/');
  await page.getByRole('link', { name: /sign in/i }).first().click();
  await expect(page).toHaveURL(/\/auth$/);
  await page.keyboard.press('Tab');
  await expect(page.locator(':focus')).toBeVisible();
  expect(errors, 'Uncaught browser errors').toEqual([]);
  writeFileSync(info.outputPath('measurements.json'), JSON.stringify({ measurements, errors }, null, 2));
  await info.attach('public-quality-measurements', { body: JSON.stringify({ measurements, errors }, null, 2), contentType: 'application/json' });
});
