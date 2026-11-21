import {test,expect} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';

test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Explicit synthetic-account write-test opt-in required');
test('deployed circles show expandable private-contact branches and link to messages',async({page},info)=>{
 test.setTimeout(180_000);
 const username='tree21'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('base64url');
 const created=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1999'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});expect(created.ok()).toBeTruthy();const user=await created.json();
 const file=resolve(__dirname,'../../../.tools/circle-tree-live-fixtures-20261121.json');const fixtures=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(file,JSON.stringify(fixtures,null,2));
 const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
 await page.goto('/circles');await expect(page.getByRole('region',{name:'Circle tree'})).toBeVisible();
 await page.getByRole('button',{name:'Create circle',exact:true}).click();await page.getByLabel('Circle name',{exact:true}).fill('Synthetic cycling circle');await page.getByRole('dialog').getByRole('button',{name:'Create circle',exact:true}).click();await expect(page.getByRole('dialog')).not.toBeVisible();
 const headers={'X-MyAaptha-Web':'1','Origin':new URL(page.url()).origin};
 const saved=await page.request.post('/api/address-book/import-reviewed',{headers,data:{consent:true,source:'csv',contacts:[{contact:{displayName:'Synthetic private rider',phones:[],emails:['tree@example.test'],groups:[]},circleNames:['Synthetic cycling circle']}]}});expect(saved.ok()).toBeTruthy();
 await page.reload();const branch=page.getByRole('button',{name:'Open Synthetic cycling circle',exact:true});await expect(branch).toHaveAttribute('aria-expanded','false');await branch.click();await expect(branch).toHaveAttribute('aria-expanded','true');
 await page.getByRole('button',{name:'Show private contacts (1)',exact:true}).click();await expect(page.getByText('Synthetic private rider',{exact:false})).toBeVisible();
 await expect(page.getByPlaceholder('Type a message')).toHaveCount(0);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 await page.screenshot({path:info.outputPath('circle-tree.png'),fullPage:true});
 const providers=await page.request.get('/api/address-book/providers');expect(providers.ok()).toBeTruthy();expect((await providers.json()).google).toBe(true);
 await page.locator('main').getByRole('link',{name:'Messages',exact:true}).click();await expect(page).toHaveURL(/\/messages\?circle=\d+$/);await expect(page.getByPlaceholder('Type a message')).toBeVisible();
 expect(errors).toEqual([]);expect((await page.request.post('/api/web-auth/logout',{headers,data:{}})).status()).toBe(204);
});
