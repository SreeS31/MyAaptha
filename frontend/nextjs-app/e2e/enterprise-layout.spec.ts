import { expect, test } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('myaaptha.web-session.metadata', JSON.stringify({ expiresIn: 900 })));
  await page.route('**/api/**', async route => {
    const path = new URL(route.request().url()).pathname;
    const post = { id: 1, authorUserId: 1, authorName: 'Workspace fixture', caption: 'A private memory in the compact workspace.', audience: 'PRIVATE', likeCount: 0, commentCount: 0, likedByMe: false, savedByMe: false, mine: true, createdAt: '2026-11-12T08:00:00Z', updatedAt: '2026-11-12T08:00:00Z', comments: [] };
    const body = path === '/api/auth/me' ? { id: 1, username: 'layout-fixture', role: 'USER', roles: ['USER'] }
      : path === '/api/settings/me' ? {}
      : path.includes('unread') ? { count: 0 }
      : path === '/api/social/feed' ? [post, { ...post, id: 2 }]
      : [];
    await route.fulfill({ json: body });
  });
});

for (const width of [390, 900, 1600]) {
  test(`diary uses the available canvas without a blank heading row at ${width}px`, async ({ page }, info) => {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto('/feed');
    await expect(page.getByRole('article').first()).toBeVisible();
    const main = await page.locator('main').boundingBox();
    const heading = await page.getByRole('heading', { name: 'Your memories', exact: true }).boundingBox();
    const firstPost = await page.getByRole('article').first().boundingBox();
    expect(main && heading && firstPost).toBeTruthy();
    expect(heading!.y - main!.y).toBeLessThan(36);
    expect(firstPost!.y - main!.y).toBeLessThan(220);
    const available = await page.locator('.workspace-content').evaluate(element => {
      const style = getComputedStyle(element);
      return element.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
    });
    expect(main!.width / available).toBeGreaterThan(.9);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await expect(page.getByRole('textbox', { name: 'Diary entry' })).toBeHidden();
    if (width >= 1300) expect(firstPost!.width).toBeLessThan(main!.width * .6);
    await page.screenshot({ path: info.outputPath(`diary-${width}-overview.png`), fullPage: true });
    const trigger = page.getByLabel('New diary entry', { exact: true });
    await trigger.click();
    const editor = await page.locator('.diary-composer').boundingBox();
    expect(editor!.width / main!.width).toBeGreaterThan(.9);
    await page.getByRole('textbox', { name: 'Diary entry' }).fill('Keep this draft when closing the composer.');
    await expect(page.getByRole('combobox', { name: 'Who can view this?' })).toHaveValue('PRIVATE');
    await trigger.click();
    await trigger.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByRole('textbox', { name: 'Diary entry' })).toHaveValue('Keep this draft when closing the composer.');
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    const accessibility = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
    expect(accessibility.violations).toEqual([]);
    await page.screenshot({ path: info.outputPath(`diary-${width}.png`), fullPage: true });
  });
}

for (const width of [390, 1600]) {
  test(`workspace pages remain within the canvas when their API is unavailable at ${width}px`, async ({ page }) => {
    test.setTimeout(180_000);
    await page.setViewportSize({ width, height: 1000 });
    await page.unroute('**/api/**');
    await page.route('**/api/**', route => route.abort());
    for (const path of ['/dashboard', '/relationship-tree', '/feed', '/health', '/finance', '/career', '/interests', '/messages', '/online-feed', '/profile', '/timeline', '/circles', '/contacts', '/settings', '/trust', '/help', '/notifications', '/reports', '/privacy', '/ai-activity', '/security-reports', '/discover', '/following', '/circle-search', '/menu-comparison', '/workspace-tools', '/people/1']) {
      await page.goto(path);
      await expect(page.locator('main')).toBeVisible();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), path).toBe(true);
      await page.evaluate(() => document.fonts.ready);
      const typography = await page.locator('main').evaluate(main => {
        const visible = (element: Element) => element.getBoundingClientRect().height > 0;
        return [...main.querySelectorAll('h1,h2,h3,button,input,select,textarea')].filter(visible).map(element => ({
          tag: element.tagName, size: getComputedStyle(element).fontSize,
          help: element.matches('.info-trigger'),
          font: getComputedStyle(element).fontFamily,
          field: element.matches('input:not([type=checkbox]):not([type=radio]):not([type=range]):not([type=color]):not([type=file]),select,textarea'),
          coarse: matchMedia('(pointer:coarse)').matches,
        }));
      });
      for (const item of typography) {
        const size = item.help ? '12px' : ({ H1: '24px', H2: '20px', H3: '18px' } as Record<string,string>)[item.tag] || (item.field && item.coarse ? '16px' : '14px');
        expect(item.size, `${path} ${item.tag}`).toBe(size);
        expect(item.font, `${path} ${item.tag}`).toContain('MyAaptha Roboto');
      }
      if (width === 390) {
        await page.getByRole('button', { name: 'Toggle main menu' }).click();
        await expect(page.locator('#workspace-navigation')).not.toHaveAttribute('inert', '');
        await page.keyboard.press('Escape');
      }
    }
  });
}
