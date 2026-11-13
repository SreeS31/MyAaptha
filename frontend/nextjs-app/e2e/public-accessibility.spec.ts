import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

test('public landing remains usable without the API', async ({ page }) => {
  await page.route('**/api/**',route=>route.abort());
  await page.goto('/');

  await expect(page.getByRole('heading', { level: 1 })).toContainText('Stay connected to what matters.');
  await expect(page.getByRole('link', { name: /sign in/i }).first()).toBeVisible();
  await expect(page.getByRole('heading',{name:'Your files, your choice.'})).toBeVisible();
  await expect(page.getByRole('link',{name:'Get started with 1 GB'})).toHaveAttribute('href','/auth');
  await expect(page.locator('.product-storage')).toContainText('up to 100 GB');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);

  const accessibility = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();

  expect(accessibility.violations).toEqual([]);
});

test('keyboard navigation reaches the main actions', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Tab');
  await expect(page.locator(':focus')).toBeVisible();
});

test('public entry screens share the application typography', async ({ page }) => {
  await page.route('**/api/**', route => route.abort());
  for (const path of ['/', '/auth', '/recover-account', '/verify-phone']) {
    await page.goto(path);
    await page.evaluate(() => document.fonts.ready);
    for (const [tag, size] of [['h1', '24px'], ['h2', '20px'], ['h3', '18px'], ['button', '14px']]) {
      for (const element of await page.locator(`main ${tag}`).all()) {
        if (await element.isVisible()) {
          await expect(element, path).toHaveCSS('font-size', size);
          await expect(element, path).toHaveCSS('font-family', /MyAaptha Roboto/);
        }
      }
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), path).toBe(true);
  }
});
