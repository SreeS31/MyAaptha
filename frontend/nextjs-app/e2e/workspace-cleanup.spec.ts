import {test,expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.beforeEach(async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:900})));
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;
  const data=path==='/api/auth/me'?{id:1,username:'Workspace member',role:'USER'}:path==='/api/settings/me'?{}:path==='/api/address-book'?{items:[],total:0,nextCursor:null}:path==='/api/address-book/providers'?{google:false,microsoft:false}:path==='/api/profile/me'?{firstName:'Workspace',surname:'Member',phoneNumber:'+19990000001',photos:[]}:path.includes('unread')?{count:0}:path.includes('preferences')?{readReceipts:true}:[];
  await route.fulfill({json:data});
 });
});
test('messages has one navigation and one working search; composer remains reachable',async({page},info)=>{
 const searches:string[]=[];
 page.on('request',request=>{if(request.url().includes('/api/network/chats/search'))searches.push(request.url());});
 await page.goto('/messages');
 await expect(page.locator('.workspace-section-tabs')).toHaveCount(0);
 await expect(page.locator('.workspace-utilities')).toHaveCount(0);
 await expect(page.locator('.workspace-topbar input')).toHaveCount(0);
 await expect(page.locator('main input[type=search]:visible')).toHaveCount(1);
 await expect(page.getByRole('heading',{level:1})).toHaveText('Messages');
 await expect(page.getByRole('button',{name:'New chat',exact:true})).toHaveCount(1);
 await page.getByLabel('Search chats and messages').fill('cycling');
 await expect.poll(()=>searches.length).toBeGreaterThan(0);
 await page.getByRole('button',{name:'New chat',exact:true}).click();
 await expect(page.getByRole('dialog',{name:'New chat',exact:true})).toBeVisible();
 await page.getByLabel('Close new chat').click();
 const axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();expect(axe.violations).toEqual([]);
 await page.getByLabel('Search chats and messages').fill('');
 await page.screenshot({path:info.outputPath('messages-clean-navigation.png'),fullPage:true});
});
test('all former section destinations remain reachable once in the main menu',async({page},info)=>{
 await page.goto('/messages');
 if(info.project.name.includes('mobile'))await page.getByRole('button',{name:'Toggle main menu'}).click();
 const sidebar=page.locator('#workspace-navigation');
 const hrefs=await sidebar.locator('a').evaluateAll(items=>items.map(a=>a.getAttribute('href')));
 expect(new Set(hrefs).size).toBe(hrefs.length);
 for(const path of ['/messages','/circles','/contacts','/circle-search','/dashboard','/timeline','/profile','/trust','/interests','/online-feed','/posts','/followers','/following','/settings','/notifications','/help','/reports','/session','/ai-activity','/moderation'])expect(hrefs,path).toContain(path);
 await sidebar.locator('a[href="/contacts"]').click();await expect(page).toHaveURL(/\/contacts$/);
 if(info.project.name.includes('mobile'))await page.getByRole('button',{name:'Toggle main menu'}).click();
 await sidebar.locator('a[href="/circles"]').click();await expect(page).toHaveURL(/\/circles$/);
 if(info.project.name.includes('mobile'))await page.getByRole('button',{name:'Toggle main menu'}).click();
 await sidebar.locator('a[href="/profile"]').click();await expect(page).toHaveURL(/\/profile$/);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});
