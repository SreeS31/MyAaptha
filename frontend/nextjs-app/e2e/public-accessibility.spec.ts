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
