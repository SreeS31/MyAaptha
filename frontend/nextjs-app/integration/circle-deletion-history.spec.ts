import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';

test('private deletions preserve access to earlier circle history',async({page,playwright})=>{
  test.setTimeout(240000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`history-${randomUUID().slice(0,8)}`,password=`History-${randomUUID()}`;
  try{
    const created=await api.post('/api/users',{data:{username,password,phoneNumber:`+1889${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(created.status()).toBe(200);
    const auth=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(auth.status()).toBe(200);
    const headers={Authorization:`Bearer ${(await auth.json()).accessToken}`};
    const circle=await api.post('/api/network/circles',{headers,data:{name:'Private deletion history',description:'Synthetic history test'}});expect(circle.status()).toBe(200);
    const id=(await circle.json()).id;const ids:number[]=[];
    for(let index=0;index<55;index++){
      const send=()=>api.post(`/api/network/circles/${id}/posts`,{headers,multipart:{message:`History entry ${index+1}`}});
      let sent=await send();
      if(sent.status()===429){
        const seconds=Number(sent.headers()['retry-after']||60);
        await page.waitForTimeout((Number.isFinite(seconds)&&seconds>0?Math.min(seconds,60):60)*1000);
        sent=await send();
      }
      expect(sent.status()).toBe(200);ids.push((await sent.json()).id);
    }
    for(const postId of ids.slice(-10))expect((await api.delete(`/api/network/circles/${id}/posts/${postId}/for-me`,{headers})).status()).toBe(204);
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await page.goto(`/dashboard?circleId=${id}`);

    const history=page.locator('.circle-expanded-content');
    await expect(history.getByText('History entry 55',{exact:true})).toHaveCount(0);
    await expect(history.getByText('History entry 6',{exact:true})).toBeVisible();
    await history.getByRole('button',{name:'Load earlier messages',exact:true}).click();
    await expect(history.getByText('History entry 1',{exact:true})).toBeVisible();
    await expect(history.getByText('History entry 55',{exact:true})).toHaveCount(0);
    await history.getByRole('button',{name:/Actions for message/}).first().click();
    await page.getByRole('menuitem',{name:'Info',exact:true}).click();
    await expect(page.getByRole('dialog',{name:'Message info'}).getByText('Read by 0 members',{exact:true}).first()).toBeVisible();
  }finally{await api.dispose();}
});
