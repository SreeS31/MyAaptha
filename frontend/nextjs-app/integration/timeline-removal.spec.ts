import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('timeline removal persists across cookie/bearer sessions and resets source overrides',async({page,playwright})=>{
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`timeline-remove-${randomUUID().slice(0,8)}`,password=`Secure-${randomUUID()}`;
  try {
    expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1886${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
    const login=await api.post('/api/auth/login',{data:{identifier:username,password}});
    expect(login.status()).toBe(200);
    const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
    const original=await (await api.get('/api/profile/me',{headers})).json();
    expect((await api.put('/api/profile/me',{headers,data:{...original,firstName:'Asha',dateOfBirth:'1990-05-20',location:'Example city'}})).status()).toBe(200);
    const before=await (await api.get('/api/profile/me',{headers})).json();
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await page.goto('/timeline');await expect(page.getByRole('heading',{name:'Born',exact:true})).toBeVisible();
    await page.getByRole('button',{name:'Add event',exact:true}).click();
    const editor=page.getByRole('dialog');await editor.getByLabel('Title',{exact:true}).fill('Temporary milestone');await editor.getByRole('button',{name:'Save event',exact:true}).click();
    await expect(page.getByRole('heading',{name:'Temporary milestone',exact:true})).toBeVisible();
    expect((await (await api.get('/api/timeline/events',{headers})).json()).some((e:{title:string})=>e.title==='Temporary milestone')).toBe(true);
    await page.getByRole('button',{name:'Edit Temporary milestone',exact:true}).click();
    page.once('dialog',dialog=>dialog.dismiss());await editor.getByRole('button',{name:'Delete event',exact:true}).click();
    await expect(editor).toBeVisible();
    page.once('dialog',dialog=>dialog.accept());await editor.getByRole('button',{name:'Delete event',exact:true}).click();
    await expect(editor).toHaveCount(0);await expect(page.getByRole('heading',{name:'Temporary milestone',exact:true})).toHaveCount(0);
    await page.reload();await expect(page.getByRole('heading',{name:'Born',exact:true})).toBeVisible();
    expect(await (await api.get('/api/timeline/events',{headers})).json()).toEqual([]);
    await page.getByRole('button',{name:'Edit Born',exact:true}).click();await editor.getByLabel('Title',{exact:true}).fill('Custom birth label');await editor.getByRole('button',{name:'Save event',exact:true}).click();
    await expect(page.getByRole('heading',{name:'Custom birth label',exact:true})).toBeVisible();await page.getByRole('button',{name:'Edit Custom birth label',exact:true}).click();
    page.once('dialog',dialog=>dialog.accept());await editor.getByRole('button',{name:'Reset to source',exact:true}).click();
    await expect(editor).toHaveCount(0);await expect(page.getByRole('heading',{name:'Born',exact:true})).toBeVisible();
    expect(await (await api.get('/api/timeline/events',{headers})).json()).toEqual([]);
    expect(await (await api.get('/api/profile/me',{headers})).json()).toEqual(before);
    expect(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)).toBe(false);
  } finally {await api.dispose();}
});
