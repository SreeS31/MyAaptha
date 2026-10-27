import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';

test.use({actionTimeout:15000});

test('core navigation, diary audience and follower lists',async({page,playwright})=>{
  test.setTimeout(120000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const password=`Memory-${randomUUID()}`;
  async function member(){const username=`memory-${randomUUID().slice(0,8)}`;const result=await api.post('/api/users',{data:{username,password,phoneNumber:`+1888${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(result.ok()).toBe(true);const user=await result.json();const auth=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(auth.ok()).toBe(true);return {...user,username,headers:{Authorization:`Bearer ${(await auth.json()).accessToken}`}};}
  try{
    const owner=await member(),model=await member();const privateMemory=`A memory for only me ${owner.username}`,publicMemory=`A shared memory ${owner.username}`;
    expect((await api.post('/api/trust/people',{headers:owner.headers,data:{userId:model.id,kind:'ROLE_MODEL'}})).ok()).toBe(true);
    expect((await api.post(`/api/trust/role-models/${model.id}/follow`,{headers:owner.headers})).ok()).toBe(true);
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(owner.username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await expect(page.getByRole('heading',{name:'Dashboard',exact:true})).toBeVisible();
    await page.goto('/feed');
    await expect(page.locator('.diary-audience-summary')).toHaveText(/Only you/);
    await page.getByRole('textbox',{name:'Diary entry',exact:true}).fill(privateMemory);
    await page.getByRole('button',{name:'Save privately',exact:true}).click();
    const entry=page.locator('.social-post').filter({hasText:privateMemory});await expect(entry).toBeVisible();await expect(entry.locator('.diary-audience-badge')).toHaveText(/Private/);
    const otherFeed=await api.get('/api/social/feed',{headers:model.headers});expect(otherFeed.ok()).toBe(true);expect(JSON.stringify(await otherFeed.json())).not.toContain(privateMemory);
    await page.getByRole('combobox',{name:'Who can view this?',exact:true}).selectOption('PUBLIC');await expect(page.locator('.diary-audience-summary')).toHaveText(/Everyone/);
    await page.getByRole('textbox',{name:'Diary entry',exact:true}).fill(publicMemory);await page.getByRole('button',{name:'Share entry',exact:true}).click();await expect(page.locator('.social-post').filter({hasText:publicMemory})).toBeVisible();await expect(page.getByRole('combobox',{name:'Who can view this?',exact:true})).toHaveValue('PRIVATE');
    await expect(page.getByRole('button',{name:'Saving…',exact:true})).toHaveCount(0);
    await page.screenshot({path:`../../.tools/preview/core-diary-${test.info().project.name}.png`,fullPage:true});
    await page.goto('/following');await expect(page.locator('.follow-person-card')).toHaveCount(1);await page.getByRole('button',{name:'Followers',exact:true}).click();await expect(page.locator('.follow-person-card')).toHaveCount(0);await page.getByRole('button',{name:'Following',exact:true}).click();await page.getByRole('button',{name:'Unfollow',exact:true}).click();await expect(page.locator('.follow-person-card')).toHaveCount(0);
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  }finally{await api.dispose();}
});
