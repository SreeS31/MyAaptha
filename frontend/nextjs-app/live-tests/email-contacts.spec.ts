import {test,expect} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';

test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Explicit synthetic-account write-test opt-in required');

test('deployed contact review preserves email-only contacts, circles and messaging wording',async({page},info)=>{
 test.setTimeout(240_000);
 const username='signin20'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('base64url');
 const created=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1999'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});
 expect(created.ok()).toBeTruthy();const user=await created.json();
 const fixturePath=resolve(__dirname,'../../../.tools/contact-signin-live-fixtures-20261120.json');
 const fixtures=existsSync(fixturePath)?JSON.parse(readFileSync(fixturePath,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(fixturePath,JSON.stringify(fixtures,null,2));
 const errors:string[]=[];page.on('pageerror',error=>errors.push(error.message));
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
 await page.goto('/contacts');await page.locator('summary').filter({hasText:'Import contacts'}).click();
 const google=page.getByRole('button',{name:'Sign in with Google',exact:true});
 await expect(google).toBeEnabled();await expect(page.locator('main input[type=email]')).toHaveCount(0);
 await page.screenshot({path:info.outputPath('provider-signin.png'),fullPage:true});
 const providers=await page.request.get('/api/address-book/providers');expect(providers.ok()).toBeTruthy();const readiness=await providers.json();
 writeFileSync(info.outputPath('provider-readiness.json'),JSON.stringify(readiness,null,2));
 if(!readiness.google){await google.click();await expect(page.locator('main').getByRole('alert')).toContainText('temporarily unavailable');}
 const csv='Name,E-mail 1 - Value,Organization 1 - Name,Group Membership\nAsha INCOIS,asha@example.test,,\nVenu INCOIS,venu@example.test,,\nCyclist,bike@example.test,,Cycling';
 await page.getByLabel('Contact file',{exact:true}).setInputFiles({name:'synthetic-email-contacts.csv',mimeType:'text/csv',buffer:Buffer.from(csv)});
 await expect(page.getByRole('heading',{name:'Review contacts (3 selected)',exact:true})).toBeVisible();
 await expect(page.getByLabel('Use circle INCOIS',{exact:true})).toBeChecked();await expect(page.getByLabel('Use circle Cycling',{exact:true})).toBeChecked();
 const before=await page.request.get('/api/address-book');expect((await before.json()).total).toBe(0);
 await page.screenshot({path:info.outputPath('contact-preview.png'),fullPage:true});
 await expect(page.getByRole('button',{name:'Import selected (3)',exact:true})).toBeDisabled();
 await page.getByRole('checkbox',{name:'I allow these contacts to be saved to my private MyAaptha address book.',exact:true}).check();
 await page.getByRole('button',{name:'Import selected (3)',exact:true}).click();await expect(page.getByRole('heading',{name:'3 saved contacts',exact:true})).toBeVisible();
 const contacts=await (await page.request.get('/api/address-book')).json();expect(contacts.total).toBe(3);expect(contacts.items.every((c:any)=>c.phones.length===0&&c.emails.length===1)).toBe(true);
 const circles=await (await page.request.get('/api/address-book/circles')).json();expect(circles.find((c:any)=>c.name==='INCOIS').privateContactCount).toBe(2);expect(circles.find((c:any)=>c.name==='Cycling').privateContactCount).toBe(1);
 const network=await (await page.request.get('/api/network/circles')).json();expect(network.every((c:any)=>c.members.length===1)).toBe(true);
 const retry=await page.request.post('/api/address-book/import-reviewed',{data:{consent:true,source:'google',contacts:contacts.items.map((c:any)=>({contact:{displayName:c.displayName,phones:c.phones,emails:c.emails,organization:c.organization,groups:c.groups},circleNames:[c.displayName==='Cyclist'?'Cycling':'INCOIS']}))},headers:{'X-MyAaptha-Web':'1','Origin':new URL(page.url()).origin}});
 expect(retry.ok()).toBeTruthy();const retried=await retry.json();expect(retried.added).toBe(0);expect(retried.unchanged).toBe(3);
 await page.goto('/messages');await expect(page.getByRole('button',{name:'Circles',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'New chat',exact:true}).click();await page.getByRole('button',{name:'New circle',exact:false}).click();
 await page.getByLabel('Circle name',{exact:true}).fill('Message circle '+username);await page.getByRole('button',{name:'Create circle',exact:true}).click();
 await expect(page.getByRole('dialog',{name:'New circle',exact:true})).toHaveCount(0);
 await expect.poll(async()=>{const result=await page.request.get('/api/network/circles');return (await result.json()).some((c:any)=>c.name==='Message circle '+username&&c.description==='Circle conversation');}).toBe(true);
 await page.screenshot({path:info.outputPath('messages-circle-wording.png'),fullPage:true});
 expect(errors).toEqual([]);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 const logout=await page.request.post('/api/web-auth/logout',{data:{},headers:{'X-MyAaptha-Web':'1','Origin':new URL(page.url()).origin}});expect(logout.status()).toBe(204);
});
