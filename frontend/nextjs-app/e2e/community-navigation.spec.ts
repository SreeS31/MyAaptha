import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('myaaptha.web-session.metadata', JSON.stringify({ expiresIn: 900 })));
  await page.route('**/api/**', async route => {
    const url = new URL(route.request().url());
    const post = { id: 1, authorUserId: 1, authorName: 'Test member', caption: 'My shared post', audience: 'PUBLIC', mine: true, likeCount: 0, commentCount: 0, likedByMe: false, savedByMe: false, createdAt: '2026-11-15T08:00:00Z', updatedAt: '2026-11-15T08:00:00Z', comments: [] };
    const body = url.pathname === '/api/auth/me' ? { id: 1, username: 'community-test', role: 'USER' }
      : url.pathname === '/api/settings/me' ? {}
      : url.pathname.includes('unread') ? { count: 0 }
      : url.pathname === '/api/social/feed' ? [post, {...post,id:2,caption:'Private diary fixture',audience:'PRIVATE'}, {...post,id:3,caption:'Another member post',mine:false}]
      : url.pathname.startsWith('/api/trust/') ? { people: [{userId:2,displayName:'Alex Member',addedAt:'2026-11-15T08:00:00Z'}], hasNext:false }
      : [];
    await route.fulfill({ json: body });
  });
});

test('my posts excludes private entries and other members; feed and diary keep their scopes', async ({ page }) => {
  await page.goto('/posts');
  await expect(page.getByRole('heading', {name:'My posts',exact:true})).toBeVisible();
  await expect(page.getByText('My shared post', {exact:true})).toBeVisible();
  await expect(page.getByText('Private diary fixture')).toHaveCount(0);
  await expect(page.getByText('Another member post')).toHaveCount(0);
  await page.goto('/online-feed');
  await expect(page.getByText('Another member post')).toBeVisible();
  await expect(page.getByText('Private diary fixture')).toHaveCount(0);
  await page.goto('/feed');
  await expect(page.getByText('Private diary fixture')).toBeVisible();
});

test('followers and following are distinct destinations with searchable lists and real unfollow requests', async ({ page }, info) => {
  await page.goto('/followers');
  await expect(page.getByRole('heading',{name:'Followers',exact:true})).toBeVisible();
  await expect(page.locator('.follow-person-card')).toContainText('Alex Member');
  await expect(page.getByRole('button',{name:'Unfollow',exact:true})).toHaveCount(0);
  await page.getByLabel('Search this page').fill('nobody');
  await expect(page.getByRole('heading',{name:'No matching names'})).toBeVisible();
  await page.getByLabel('Search this page').fill('Alex');
  await expect(page.locator('.follow-person-card')).toHaveCount(1);
  const axe = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();
  expect(axe.violations).toEqual([]);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  await page.screenshot({path:info.outputPath('followers.png'),fullPage:true});
  await page.goto('/following');
  const request = page.waitForRequest(request=>request.method()==='DELETE'&&request.url().includes('/api/trust/role-models/2/follow'));
  await page.getByRole('button',{name:'Unfollow',exact:true}).click();
  await request;
  await expect(page.getByRole('button',{name:'Unfollow',exact:true})).toBeEnabled();
});
