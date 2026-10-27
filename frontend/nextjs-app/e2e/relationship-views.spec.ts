import { expect, test } from '@playwright/test';

test('original tree and chain are independent views of the same relationships', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => localStorage.setItem('myaaptha.web-session.metadata', JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
  const relationships = [
    {id:1,type:'Friend',visibilityScope:'FRIENDS',person:{id:11,displayName:'Alex',gender:'MALE',accountStatus:'ACTIVE'}},
    {id:2,type:'Sister',relativeToUserId:11,visibilityScope:'FRIENDS',person:{id:12,displayName:'Maya',gender:'FEMALE',accountStatus:'ACTIVE'}},
  ];
  await page.route('**/api/**', async route => {
    const path = new URL(route.request().url()).pathname;
    const data = path === '/api/auth/me' ? {id:1,username:'Robin',role:'USER'}
      : path === '/api/profile/me' ? {gender:'OTHER',photos:[],profilePhoto:null}
      : path === '/api/network/relationships' ? relationships
      : path.includes('unread') ? {count:0} : [];
    await route.fulfill({json:data,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:3100','Access-Control-Allow-Credentials':'true','Access-Control-Allow-Headers':'Content-Type,X-MyAaptha-Web'}});
  });
  await page.goto('/relationship-tree');
  const views = page.getByRole('group', {name:'Relationship view', exact:true});
  await expect(views.getByRole('button', {name:'Family tree',exact:true})).toHaveAttribute('aria-pressed','true');
  await expect(page.getByRole('button', {name:/Modern/})).toBeVisible();
  await views.getByRole('button', {name:'Chain explorer',exact:true}).click();
  const chain = page.getByRole('region', {name:'Relationship chain explorer'});
  await expect(chain).toBeVisible();
  await expect(chain.getByRole('button', {name:'View details for Maya',exact:true})).toHaveCount(0);
  await chain.getByRole('button', {name:'View details for Alex',exact:true}).click();
  await expect(chain.getByRole('complementary', {name:'Alex details'})).toBeVisible();
  await expect(chain.getByRole('button', {name:'View details for Maya',exact:true})).toHaveCount(0);
  const expand = chain.getByRole('button', {name:'Expand branch for Alex',exact:true});
  await expect(expand).toHaveCSS('background-color', 'rgb(56, 118, 214)');
  await expect(chain.getByText('End of available chain', {exact:true})).toHaveCount(0);
  await expand.click();
  await expect(chain.getByRole('button', {name:'View details for Maya',exact:true})).toBeVisible();
  await expect(chain.getByRole('img', {name:'Maya: end of available chain'})).toHaveCSS('border-top-color', 'rgb(213, 62, 131)');
  await views.getByRole('button', {name:'Family tree',exact:true}).click();
  await expect(page.getByRole('button', {name:/Modern/})).toBeVisible();
  await expect(chain).toHaveCount(0);
  expect(errors).toEqual([]);
});
