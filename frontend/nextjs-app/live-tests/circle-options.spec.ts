import {test,expect,BrowserContext,Page} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Requires removable synthetic-account live-write opt-in');
test('live circle menu saves settings, manages admins and keeps private history separate',async({browser},info)=>{
 test.setTimeout(240_000);const contexts:BrowserContext[]=[],accounts:{id:number;username:string;page:Page}[]=[];
 try{
  for(let index=0;index<2;index++){
   const context=await browser.newContext({baseURL:info.project.use.baseURL,viewport:info.project.use.viewport,isMobile:info.project.use.isMobile,hasTouch:info.project.use.hasTouch,userAgent:info.project.use.userAgent});contexts.push(context);
   const page=await context.newPage(),username='cm23'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('base64url');
   const registered=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1998'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});expect(registered.ok()).toBe(true);const user=await registered.json();
   const file=resolve(__dirname,'../../../.tools/circle-menu-live-fixtures-20261123.json'),fixtures=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(file,JSON.stringify(fixtures,null,2));accounts.push({id:user.id,username,page});
   await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Sign in',exact:true}).click();await expect(page).not.toHaveURL(/\/auth/);
  }
  const [owner,member]=accounts,headers={'X-MyAaptha-Web':'1',Origin:String(info.project.use.baseURL)};
  const relation=await owner.page.request.post('/api/network/relationships',{headers,data:{relatedUserId:member.id,type:'Friend',visibilityScope:'FRIENDS'}});expect(relation.ok()).toBe(true);
  const created=await owner.page.request.post('/api/network/chats/groups',{headers,data:{name:'Synthetic menu '+owner.username,memberIds:[]}});expect(created.ok()).toBe(true);const circle=await created.json(),path='/api/network/chats/workspace/CIRCLE/'+circle.id;
  const rows=await (await owner.page.request.get('/api/network/relationships')).json(),memberName=rows.find((r:{person:{id:number}})=>r.person.id===member.id).person.displayName;
  await owner.page.goto('/messages?circle='+circle.id);const menu=owner.page.getByLabel('Circle options',{exact:true});await menu.click();await owner.page.locator('.chat-thread-options').getByRole('button',{name:'Add member',exact:true}).click();
  const pane=owner.page.getByRole('complementary',{name:'Circle info'});await pane.getByRole('button',{name:'+ '+memberName,exact:true}).click();await pane.getByLabel('Actions for '+memberName,{exact:true}).click();await pane.getByRole('button',{name:'Make admin',exact:true}).click();await expect(pane.getByText('Admin',{exact:true})).toBeVisible();
  await owner.page.screenshot({path:info.outputPath('live-circle-info.png'),fullPage:true});await pane.getByRole('button',{name:'Close circle info',exact:true}).click();
  await menu.click();await owner.page.getByRole('button',{name:'Chat theme',exact:true}).click();await owner.page.getByRole('dialog').getByRole('button',{name:'Ocean',exact:true}).click();expect((await (await owner.page.request.get(path)).json()).theme).toBe('OCEAN');expect((await (await member.page.request.get(path)).json()).theme).toBe('DEFAULT');
  await menu.click();await owner.page.getByRole('button',{name:'Disappearing messages',exact:true}).click();await owner.page.getByRole('dialog').getByRole('button',{name:'7 days',exact:true}).click();expect((await (await member.page.request.get(path)).json()).disappearingSeconds).toBe(604800);
  await owner.page.getByLabel('Message text',{exact:true}).fill('Synthetic circle history');await owner.page.getByRole('button',{name:'Send message',exact:true}).click();await expect.poll(async()=>((await (await member.page.request.get(path+'/export')).json()) as unknown[]).length).toBe(1);
  await menu.click();await owner.page.getByRole('button',{name:'Clear chat',exact:true}).click();await owner.page.getByRole('dialog').getByRole('button',{name:'Clear for me',exact:true}).click();expect(await (await owner.page.request.get(path+'/export')).json()).toEqual([]);expect((await (await member.page.request.get(path+'/export')).json()).length).toBe(1);
  await menu.click();await owner.page.getByRole('button',{name:'Exit circle',exact:true}).click();await owner.page.getByRole('dialog').getByLabel('Transfer creator role',{exact:true}).selectOption(String(member.id));await owner.page.getByRole('dialog').getByRole('button',{name:'Exit circle',exact:true}).click();await expect.poll(()=>owner.page.request.get(path).then(r=>r.status())).toBe(403);
  const solo=await (await member.page.request.get(path)).json();expect(solo.creator).toBe(true);expect(solo.solo).toBe(true);expect((await member.page.request.post(path+'/exit',{headers,data:{deleteEmptyCircle:true}})).ok()).toBe(true);
 }finally{for(const context of contexts)await context.close();}
});
