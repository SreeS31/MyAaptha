import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('queue pages and filters use the shared contract; cancelled notes never update',async({page,playwright})=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`queue-${randomUUID().slice(0,8)}`,password=`Secret-${randomUUID()}`;
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1883${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
  expect((await api.get('/api/moderation/reports/queue',{headers})).status()).toBe(403);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  expect((await page.request.get('/api/moderation/reports/queue')).status()).toBe(403);
  // No live administrator role is granted. Exercise the UI with synthetic responses;
  // real admin pagination and boundaries are covered by the isolated database suite.
  await page.route('**/api/auth/me',route=>route.fulfill({json:{id:999,username:'Synthetic moderator',role:'ADMIN'}}));
  const requests:string[]=[];let writes=0;
  const report=(id:number,status='OPEN')=>({id,reason:'SPAM',status,details:`Synthetic report ${id}`,createdAt:'2026-10-01T00:00:00Z',moderatorNotes:''});
  await page.route('**/api/moderation/reports/queue?*',route=>{const url=new URL(route.request().url()),status=url.searchParams.get('status')!;requests.push(url.search);return route.fulfill({json:status==='OPEN'?(url.searchParams.has('beforeId')?{items:[report(1)],nextCursor:null}:{items:[report(3)],nextCursor:3}):{items:[report(2,status)],nextCursor:null}});});
  await page.route('**/api/moderation/reports/3',route=>{writes++;return route.fulfill({json:report(3,'RESOLVED')});});
  await page.goto('/moderation');await expect(page.getByText('Synthetic report 3',{exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.getByRole('button',{name:'Load more reports',exact:true}).click();await expect(page.getByText('Synthetic report 1',{exact:true})).toBeVisible();expect(requests.some(url=>url.includes('beforeId=3'))).toBe(true);
  page.once('dialog',dialog=>dialog.dismiss());await page.getByRole('button',{name:'Resolve',exact:true}).first().click();expect(writes).toBe(0);
  await page.getByRole('button',{name:'resolved',exact:true}).click();await expect(page.getByText('Synthetic report 2',{exact:true})).toBeVisible();expect(requests.at(-1)).toContain('status=RESOLVED');expect(requests.at(-1)).not.toContain('beforeId');expect(writes).toBe(0);await expect(page.getByText('Synthetic report 3',{exact:true})).toHaveCount(0);
  await page.route('**/api/moderation/reports/queue?*',route=>route.fulfill({status:403,json:{message:'Administrator access required'}}));await page.getByRole('button',{name:'Refresh queue',exact:true}).click();await expect(page.getByText('Synthetic report 2',{exact:true})).toHaveCount(0);await expect(page.getByRole('status')).toContainText('Administrator access required');
 }finally{await api.dispose();}
});
