import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('only the approved requester sees document controls and revocation blocks the next open',async({page,playwright})=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const password=`Emergency-${randomUUID()}`;
 async function member(){const username=`emergency-${randomUUID().slice(0,8)}`;const user=await api.post('/api/users',{data:{username,password,phoneNumber:`+1889${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(user.status()).toBe(200);const id=(await user.json()).id as number;const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);return {id,username,headers:{Authorization:`Bearer ${(await login.json()).accessToken}`}};}
 try{
   const owner=await member(),requester=await member(),approver=await member();
   for(const star of [requester,approver])expect((await api.post('/api/trust/people',{headers:owner.headers,data:{userId:star.id,kind:'STAR'}})).status()).toBe(200);
   const post=await api.post('/api/social/posts',{headers:owner.headers,multipart:{caption:'Synthetic private emergency attachment',audience:'PRIVATE',retentionDays:'1',file:{name:'owner-fixture.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.4\nSynthetic local fixture\n%%EOF')}}});expect(post.status(),await post.text()).toBe(200);
   const start=await api.post('/api/trust/emergencies',{headers:requester.headers,data:{ownerUserId:owner.id,reason:'Synthetic local emergency access acceptance scenario'}});expect(start.status()).toBe(200);const request=await start.json();expect(request.canDecide).toBe(false);expect(request.canViewDocuments).toBe(false);
   const decision=await api.post(`/api/trust/emergencies/${request.id}/decision`,{headers:approver.headers,data:{approved:true}});expect(decision.status()).toBe(200);expect((await decision.json()).canViewDocuments).toBe(false);
   const ownerRequests=await (await api.get('/api/trust/emergencies',{headers:owner.headers})).json();expect(ownerRequests.find((r:{id:number})=>r.id===request.id).canViewDocuments).toBe(false);
   await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(requester.username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
   await page.goto('/trust');await page.getByRole('button',{name:'View emergency documents',exact:true}).click();await expect(page.getByRole('heading',{name:'Time-limited emergency documents'})).toBeVisible();
   expect((await api.get(`/api/trust/emergencies/${request.id}/documents`,{headers:approver.headers})).status()).toBe(403);
   expect((await api.delete(`/api/trust/people/${requester.id}?kind=STAR`,{headers:owner.headers})).status()).toBe(204);
   await page.getByRole('button',{name:'owner-fixture.pdf'}).click();await expect(page.getByRole('status')).toContainText('Emergency access is not active');await expect(page.getByRole('heading',{name:'Time-limited emergency documents'})).toHaveCount(0);
   await page.reload();await expect(page.getByRole('heading',{name:'Emergency requests',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'View emergency documents',exact:true})).toHaveCount(0);
 }finally{await api.dispose();}
});
