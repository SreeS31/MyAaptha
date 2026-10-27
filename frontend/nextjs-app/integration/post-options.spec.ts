import {test,expect as baseExpect} from './fixtures';
import {randomUUID} from 'node:crypto';
const expect=baseExpect.configure({timeout:15000});
test.use({actionTimeout:15000});

test('post options persist emoji reactions and private pins/stars and preserve real actions',async({page,playwright,context},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'}),username=`options-${randomUUID().slice(0,8)}`,password=`Options-${randomUUID()}`,ids:number[]=[];let headers:Record<string,string>={};
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1882${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);const auth=await(await api.post('/api/auth/login',{data:{identifier:username,password}})).json();headers={Authorization:`Bearer ${auth.accessToken}`};
  const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=','base64');
  for(const caption of ['Options fixture','A newer fixture']){const result=await api.post('/api/social/posts',{headers,multipart:{caption,audience:'PRIVATE',file:{name:'options.png',mimeType:'image/png',buffer:image}}});expect(result.ok()).toBe(true);ids.push((await result.json()).id);}
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);await page.goto('/online-feed');const post=page.locator(`#feed-post-${ids[0]}`);
  const open=async()=>{await post.getByLabel('Post options',{exact:true}).click();await expect(post.getByRole('menu',{name:'Post actions'})).toBeVisible();};
  await open();for(const label of ['Post info','Reply','Copy','React','Download','Forward','Pin for me','Ask MyAaptha','Star','Edit','Delete'])await expect(post.getByRole('menuitem',{name:label,exact:true})).toBeVisible();
  await post.getByRole('button',{name:'React ❤️',exact:true}).click();await expect(post.locator('.feed-reaction-summary')).toContainText('❤️ 1');
  await open();await post.getByRole('button',{name:'More reactions',exact:true}).click();await post.getByLabel('Custom emoji reaction').fill('👩🏽‍💻');await post.getByRole('button',{name:'React',exact:true}).click();await expect(post.locator('.feed-reaction-summary')).toContainText('👩🏽‍💻 1');
  await open();await post.getByRole('menuitem',{name:'Pin for me',exact:true}).click();await expect(post.locator('.feed-pinned-label')).toBeVisible();await expect(page.locator('.social-feed>article').first()).toHaveAttribute('id',`feed-post-${ids[0]}`);
  await open();await post.getByRole('menuitem',{name:'Star',exact:true}).click();await expect(post.getByRole('button',{name:'Unsave post',exact:true})).toHaveAttribute('aria-pressed','true');await page.reload();await expect(post.locator('.feed-pinned-label')).toBeVisible();await expect(post.getByRole('button',{name:'Unsave post',exact:true})).toHaveAttribute('aria-pressed','true');
  const saved=(await(await api.get('/api/social/feed',{headers})).json()).find((p:any)=>p.id===ids[0]);expect(saved.myReaction).toBe('👩🏽‍💻');expect(saved.likeCount).toBe(1);expect(saved.pinned).toBe(true);expect(saved.savedByMe).toBe(true);
  await open();await post.getByRole('menuitem',{name:'Post info',exact:true}).click();const details=page.getByRole('dialog',{name:'Post info',exact:true});await expect(details).toContainText(username);await expect(details).toContainText('👩🏽‍💻 1');await details.getByRole('button',{name:'Close',exact:true}).click();
  await open();const downloading=page.waitForEvent('download');await post.getByRole('menuitem',{name:'Download',exact:true}).click();expect((await downloading).suggestedFilename()).toBe('options.png');
  await context.grantPermissions(['clipboard-read','clipboard-write']);await open();await post.getByRole('menuitem',{name:'Copy',exact:true}).click();await expect(page.getByRole('status').filter({hasText:'Copied to clipboard.'})).toBeVisible();expect(await page.evaluate(()=>navigator.clipboard.readText())).toBe('Options fixture');
  await open();await post.getByRole('menuitem',{name:'Reply',exact:true}).click();await expect(post.getByRole('textbox',{name:'Write a comment'})).toBeFocused();
  await open();await post.getByRole('menuitem',{name:'Forward',exact:true}).click();await expect(page.getByRole('heading',{name:'Send privately'})).toBeVisible();await page.getByRole('button',{name:'Close',exact:true}).click();
  await open();await page.screenshot({path:`../../.tools/preview/post-options-${info.project.name}.png`});await post.getByLabel('Post options',{exact:true}).press('Escape');await expect(post.getByLabel('Post options',{exact:true})).toBeFocused();
  page.once('dialog',dialog=>dialog.dismiss());await open();await post.getByRole('menuitem',{name:'Delete',exact:true}).click();await expect(post).toBeVisible();
  page.once('dialog',dialog=>dialog.accept('Options fixture edited'));await open();await post.getByRole('menuitem',{name:'Edit',exact:true}).click();await expect(post.locator('.social-caption')).toHaveText('Options fixture edited');
  let sent=false;page.on('request',r=>{if(r.method()==='POST'&&r.url().includes('/api/ai/help/chat'))sent=true;});await open();await post.getByRole('menuitem',{name:'Ask MyAaptha',exact:true}).click();await expect(page).toHaveURL(/\/help$/);await expect(page.getByLabel('Your question',{exact:true})).toHaveValue(/Options fixture/);expect(sent).toBe(false);
 }finally{for(const id of ids)await api.delete(`/api/social/posts/${id}`,{headers});await api.dispose();}
});

test('reaction and pin APIs preserve private audiences and account-specific flags',async({playwright,page},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'}),ids:number[]=[],members:Array<{username:string;password:string;headers:Record<string,string>}> = [];
 try{
  for(let i=0;i<2;i++){const username=`options-access-${randomUUID().slice(0,8)}`,password=`Options-${randomUUID()}`;expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1882${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);const login=await(await api.post('/api/auth/login',{data:{identifier:username,password}})).json();members.push({username,password,headers:{Authorization:`Bearer ${login.accessToken}`}});}
  for(const audience of ['PUBLIC','PRIVATE']){const response=await api.post('/api/social/posts',{headers:members[0].headers,multipart:{caption:`Options authorization ${audience}`,audience}});expect(response.ok()).toBe(true);ids.push((await response.json()).id);}
  expect((await api.put(`/api/social/posts/${ids[1]}/reaction`,{headers:members[1].headers,data:{emoji:'👍'}})).status()).toBe(403);expect((await api.put(`/api/social/posts/${ids[1]}/pin`,{headers:members[1].headers,data:{pinned:true}})).status()).toBe(403);
  expect((await api.put(`/api/social/posts/${ids[0]}/reaction`,{headers:members[1].headers,data:{emoji:'hello'}})).status()).toBe(400);
  for(let i=0;i<2;i++){const response=await api.put(`/api/social/posts/${ids[0]}/reaction`,{headers:members[1].headers,data:{emoji:'😂'}});expect(response.status()).toBe(200);expect((await response.json()).likeCount).toBe(1);}
  expect((await api.put(`/api/social/posts/${ids[0]}/pin`,{headers:members[1].headers,data:{pinned:true}})).status()).toBe(200);
  const owner=(await(await api.get('/api/social/feed',{headers:members[0].headers})).json()).find((p:any)=>p.id===ids[0]);expect(owner.pinned).toBe(false);expect(owner.myReaction).toBe(null);expect(owner.reactions['😂']).toBe(1);
  expect((await api.delete(`/api/social/posts/${ids[0]}`,{headers:members[1].headers})).status()).toBe(403);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(members[1].username);await page.getByLabel('Password',{exact:true}).fill(members[1].password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);await page.goto('/online-feed');const post=page.locator(`#feed-post-${ids[0]}`);await post.getByLabel('Post options',{exact:true}).click();await expect(post.getByRole('menuitem',{name:'Report',exact:true})).toBeVisible();await expect(post.getByRole('menuitem',{name:'Edit',exact:true})).toHaveCount(0);await expect(post.getByRole('menuitem',{name:'Delete',exact:true})).toHaveCount(0);await expect(post.getByRole('menuitem',{name:'Unpin for me',exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)).toBe(false);
 }finally{for(const id of ids)await api.delete(`/api/social/posts/${id}`,{headers:members[0]?.headers});await api.dispose();}
});
