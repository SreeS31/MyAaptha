import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';

test('browser cookies and mobile bearer sessions share account data and changes',async({page,playwright})=>{
  test.setTimeout(120000);
  const mobile=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`account-sync-${randomUUID().slice(0,10)}`,password=`Sync-${randomUUID()}`;
  const created=await mobile.post('/api/users',{data:{username,password,phoneNumber:`+1883${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});
  expect(created.status()).toBe(200);
  const auth=await mobile.post('/api/auth/login',{data:{identifier:username,password}});
  expect(auth.status()).toBe(200);
  const headers={Authorization:`Bearer ${(await auth.json()).accessToken}`};
  try{
    await page.goto('/auth');
    await page.getByLabel('Username or mobile number',{exact:true}).fill(username);
    await page.getByLabel('Password',{exact:true}).fill(password);
    await page.getByRole('button',{name:'Continue',exact:true}).click();
    await expect(page).toHaveURL(/dashboard/);
    for(const path of ['/api/auth/me','/api/profile/me','/api/settings/me','/api/notifications/preferences','/api/ai/preferences','/api/uploads/policy','/api/network/relationships','/api/network/circles','/api/network/messages/preferences','/api/network/messages/conversations','/api/network/chats/circles','/api/address-book','/api/trust/role-models','/api/health/dashboard','/api/finance/summary','/api/network/calls/ice']){
      const direct=await mobile.get(path,{headers});const web=await page.request.get(path);
      expect(direct.status(),`mobile ${path}`).toBe(200);expect(web.status(),`web ${path}`).toBe(200);
      const webBody=await web.json(),mobileBody=await direct.json();
      if(path==='/api/network/calls/ice'){
        // Relay credentials expire and are generated per request: compare shared policy, not timestamps.
        expect(webBody.relayConfigured).toBe(mobileBody.relayConfigured);
        expect(webBody.iceServers.map((server:any)=>server.urls)).toEqual(mobileBody.iceServers.map((server:any)=>server.urls));
        for(const config of [webBody,mobileBody])if(config.relayConfigured){
          expect(config.credentialsExpireAt).toBeGreaterThan(0);
          expect(config.iceServers.some((server:any)=>typeof server.username==='string'&&typeof server.credential==='string')).toBe(true);
        }
      }else expect(webBody,path).toEqual(mobileBody);
    }
    const settings=await (await mobile.get('/api/settings/me',{headers})).json();
    const changed={...settings,compactLayout:true,reducedMotion:true,timeZone:'Asia/Kolkata'};
    expect((await mobile.put('/api/settings/me',{headers,data:changed})).status()).toBe(200);
    await page.goto('/settings');
    await expect(page.getByRole('checkbox',{name:'Compact spacing',exact:true})).toBeChecked();
    await page.getByRole('checkbox',{name:'Compact spacing',exact:true}).uncheck();
    await page.getByRole('button',{name:'Save settings',exact:true}).click();
    await expect(page.getByRole('status').filter({hasText:'Settings saved.'})).toBeVisible();
    expect((await (await mobile.get('/api/settings/me',{headers})).json()).compactLayout).toBe(false);
    // Change finance while its page remains open: focus must refresh the server state.
    await page.goto('/finance');
    const merchant=`Cross-client ${username}`;
    const transaction=await mobile.post('/api/finance/transactions',{headers,data:{amount:18,direction:'EXPENSE',category:'OTHER',merchant,description:'Synchronization fixture',occurredAt:new Date().toISOString(),source:'MANUAL'}});
    expect(transaction.status()).toBe(200);
    await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
    await expect(page.getByText(merchant,{exact:true})).toBeVisible();
    const id=(await transaction.json()).id;
    expect((await mobile.delete(`/api/finance/transactions/${id}`,{headers})).status()).toBe(204);
    await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
    await expect(page.getByText(merchant,{exact:true})).toHaveCount(0);
    expect((await mobile.get('/api/settings/me')).status()).toBe(401);
    expect((await mobile.get('/api/admin/upload-levels',{headers})).status()).toBe(403);
  }finally{await mobile.dispose();}
});
