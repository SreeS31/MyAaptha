import {test,expect} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';

// The normal live suite remains read-only. This separate opt-in creates only synthetic accounts.
test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Requires explicit synthetic-account write-test opt-in');
test('deployed workspace has one navigation surface and preserves account access',async({page},info)=>{
 test.setTimeout(240_000);
 const username='uicleanup18'+randomBytes(5).toString('hex');const password=randomBytes(24).toString('base64url');
 const created=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1999'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});
 expect(created.ok()).toBeTruthy();const user=await created.json();
 const path=resolve(__dirname,'../../../.tools/workspace-live-fixtures-20261118.json');
 const fixtures=existsSync(path)?JSON.parse(readFileSync(path,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(path,JSON.stringify(fixtures,null,2));
 const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
 const profile=await page.request.get('/api/auth/me');expect(profile.ok()).toBeTruthy();expect((await profile.json()).id).toBe(user.id);
 for(const route of ['/messages','/contacts','/circles','/career','/interests','/profile','/finance','/health']){
  await page.goto(route);await expect(page.locator('main:visible')).toHaveCount(1);
  await expect(page.locator('.workspace-section-tabs,.workspace-utilities,.workspace-global-search')).toHaveCount(0);
  const hrefs=await page.locator('#workspace-navigation a').evaluateAll(items=>items.map(item=>item.getAttribute('href')));expect(new Set(hrefs).size,route).toBe(hrefs.length);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),route).toBe(true);
 }
 await page.goto('/messages');await expect(page.locator('main input[type=search]:visible')).toHaveCount(1);await expect(page.getByRole('button',{name:'New chat',exact:true})).toHaveCount(1);
 await page.getByRole('button',{name:'New chat',exact:true}).click();await expect(page.getByRole('dialog',{name:'New chat',exact:true})).toBeVisible();await page.getByLabel('Close new chat').click();
 await page.screenshot({path:info.outputPath('deployed-messages-cleanup.png'),fullPage:true});
 expect(errors).toEqual([]);
 const logout=await page.request.post('/api/web-auth/logout',{data:{},headers:{'X-MyAaptha-Web':'1','Origin':new URL(page.url()).origin}});expect(logout.status()).toBe(204);
});
