import {test,expect} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';

// The normal live suite remains read-only. This separate opt-in creates only synthetic accounts.
test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Requires explicit synthetic-account write-test opt-in');
test('deployed dashboard and workspaces keep compact copy and account access',async({page},info)=>{
 test.setTimeout(240_000);
 const username='copycheck18'+randomBytes(5).toString('hex');const password=randomBytes(24).toString('base64url');
 const created=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1999'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});
 expect(created.ok()).toBeTruthy();const user=await created.json();
 const path=resolve(__dirname,'../../../.tools/copy-live-fixtures-20261118.json');
 const fixtures=existsSync(path)?JSON.parse(readFileSync(path,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(path,JSON.stringify(fixtures,null,2));
 const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
 const profile=await page.request.get('/api/auth/me');expect(profile.ok()).toBeTruthy();expect((await profile.json()).id).toBe(user.id);
 for(const route of ['/dashboard','/timeline','/feed','/reports','/notifications','/messages','/contacts','/circles','/career','/interests','/profile','/finance','/health']){
  await page.goto(route);await expect(page.locator('main:visible')).toHaveCount(1);
  await expect(page.locator('.workspace-section-tabs,.workspace-utilities,.workspace-global-search')).toHaveCount(0);
  if(route==='/circles')await expect(page.getByRole('searchbox',{name:'Search circles',exact:true})).toBeVisible();
  if(route==='/contacts')await expect(page.getByRole('searchbox',{name:'Search contacts',exact:true})).toBeVisible();
  const hrefs=await page.locator('#workspace-navigation a').evaluateAll(items=>items.map(item=>item.getAttribute('href')));expect(new Set(hrefs).size,route).toBe(hrefs.length);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),route).toBe(true);
 }
 await page.goto('/dashboard');
 await expect(page.locator('.user-dashboard-metrics article')).toHaveCount(5);
 const network=page.getByRole('region',{name:'Network summary',exact:true});
 await expect(network.getByRole('heading')).toHaveText('Network');
 await expect(network.getByText('No relationships',{exact:true})).toBeVisible();
 await network.getByRole('button',{name:'Circles',exact:true}).click();
 await expect(network.getByText('No circles',{exact:true})).toBeVisible();
 await expect(page.locator('.timeline-dashboard-preview').getByText('No events',{exact:true})).toBeVisible();
 await expect(page.getByRole('navigation',{name:'Dashboard shortcuts'})).toHaveCount(0);
 await expect(page.getByText('Your network at a glance',{exact:true})).toHaveCount(0);
 await expect(page.getByText('Counts from your saved relationships.',{exact:true})).toHaveCount(0);
 await page.screenshot({path:info.outputPath('deployed-dashboard-compact.png'),fullPage:true});
 const health=await page.request.get('/api/health/dashboard');expect(health.ok()).toBeTruthy();expect((await health.json()).disclaimer).toBe('Lab reference ranges only. Not a diagnosis; consult a clinician.');
 const finance=await page.request.get('/api/finance/summary');expect(finance.ok()).toBeTruthy();expect((await finance.json()).disclaimer).toBe('Not financial advice. Consult a qualified adviser.');
 await page.goto('/messages');await expect(page.locator('main input[type=search]:visible')).toHaveCount(1);await expect(page.getByRole('button',{name:'New chat',exact:true})).toHaveCount(1);
 await page.getByRole('button',{name:'New chat',exact:true}).click();await expect(page.getByRole('dialog',{name:'New chat',exact:true})).toBeVisible();await page.getByLabel('Close new chat').click();
 await page.screenshot({path:info.outputPath('deployed-messages-compact.png'),fullPage:true});
 expect(errors).toEqual([]);
 const logout=await page.request.post('/api/web-auth/logout',{data:{},headers:{'X-MyAaptha-Web':'1','Origin':new URL(page.url()).origin}});expect(logout.status()).toBe(204);
});
