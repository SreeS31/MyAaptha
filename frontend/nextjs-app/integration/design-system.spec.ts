import {expect,test} from './fixtures';
import AxeBuilder from '@axe-core/playwright';
import {randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
test.use({actionTimeout:15000});
test('all application routes share typography and fit the viewport',async({page,playwright},info)=>{
 test.setTimeout(600000);
 const folder=`../../.tools/ui-review-current/${info.project.name}`;mkdirSync(folder,{recursive:true});
 const audit:any[]=[];
 const pageErrors:string[]=[];page.on('pageerror',error=>pageErrors.push(error.message));
 async function review(route:string,name=route.replaceAll('/','-')||'home'){
  await page.goto(route);await page.locator('main').first().waitFor();await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(500);
  if(name.startsWith('admin-')||route.startsWith('/people/'))await page.locator('main details').evaluateAll(nodes=>nodes.forEach(node=>{(node as HTMLDetailsElement).open=true;}));
  const help=page.locator('main .info-trigger').first();
  if(await help.count()){
   await help.click();await expect(page.locator('main .info-panel').first()).toBeVisible();
   await page.keyboard.press('Escape');await expect(page.locator('main .info-panel')).toHaveCount(0);
  }
  if(route==='/circles'){
   const create=page.getByRole('button',{name:'Create circle',exact:true});await create.click();
   const dialog=page.getByRole('dialog',{name:'Create circle',exact:true});
   await expect(dialog.getByLabel('Circle name',{exact:true})).toBeFocused();
   await page.keyboard.press('Escape');await expect(dialog).toBeHidden();await expect(create).toBeFocused();
  }
  if(route==='/health'){
   await page.getByRole('button',{name:'Add a measurement',exact:true}).click();
   await expect(page.getByLabel('Report name',{exact:true})).toBeVisible();
   await page.getByRole('button',{name:'Close manual entry',exact:true}).click();
   await expect(page.getByLabel('Report name',{exact:true})).toBeHidden();
  }
  if(name==='admin-dashboard'){
   for(const height of await page.locator('.admin-records-grid>.card').evaluateAll(cards=>cards.map(card=>card.getBoundingClientRect().height)))expect.soft(height,'Admin record panels stay bounded').toBeLessThanOrEqual(421);
  }
  expect.soft(pageErrors,route+' runtime errors').toEqual([]);
  const record=await page.evaluate(()=>{
   const visible=(el:Element)=>{const r=el.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(el).visibility!=='hidden';};
   const headings=Array.from(document.querySelectorAll('main h1,main h2,main h3')).filter(visible).map(el=>({tag:el.tagName,size:getComputedStyle(el).fontSize,text:el.textContent?.slice(0,70)}));
   const controls=Array.from(document.querySelectorAll('button,input,select,textarea')).filter(visible).map(el=>({size:getComputedStyle(el).fontSize,tag:el.tagName,type:(el as HTMLInputElement).type,font:getComputedStyle(el).fontFamily,text:el.getAttribute('aria-label')||el.textContent?.slice(0,50)}));
   return {path:location.pathname,headings,controls,fontLoaded:document.fonts.check('14px "MyAaptha Roboto"'),overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth+2};
  });audit.push(record);
  expect.soft(record.path,route).toBe(route);
  expect.soft(record.fontLoaded,route+' font').toBe(true);
  expect.soft(record.overflow,route+' horizontal overflow').toBe(false);
  if(route==='/feed'){
   const composer=page.locator('.diary-composer');
   const bounds=await composer.boundingBox();
   expect.soft(bounds?.y,'Diary editor should be visible near the top').toBeLessThan(info.project.name==='desktop'?280:390);
   await expect(page.locator('.story-strip')).toBeHidden();
   await page.locator('.story-composer summary').click();
   await expect(page.getByLabel('Caption',{exact:true})).toBeVisible();
   await page.locator('.story-composer summary').click();
   await expect(page.getByLabel('Caption',{exact:true})).toBeHidden();
  }
  for(const h of record.headings)expect.soft(h.size,route+' '+h.text).toBe(h.tag==='H1'?'24px':h.tag==='H2'?'20px':'18px');
  for(const c of record.controls){expect.soft(c.size,route+' '+c.text).toBe(info.project.name==='mobile-web'&&['INPUT','SELECT','TEXTAREA'].includes(c.tag)&&!['checkbox','radio','file','range','color'].includes(c.type)?'16px':'14px');expect.soft(c.font,route+' font').toContain('MyAaptha Roboto');}
  const accessibility=await new AxeBuilder({page}).withRules(['color-contrast','label','select-name','button-name','input-button-name','aria-input-field-name']).analyze();
  (record as any).contrast=accessibility.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))}));
  expect.soft(accessibility.violations,route+' contrast').toEqual([]);
  writeFileSync(`${folder}/audit.json`,JSON.stringify(audit,null,2));
  await page.screenshot({path:`${folder}/${name}.png`,fullPage:true});
 }
 for(const route of ['/','/auth','/recover-account','/verify-phone'])await review(route);
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`visual-${randomUUID().slice(0,8)}`,password=`Visual-${randomUUID()}`;
 const registered=await api.post('/api/users',{data:{username,password,phoneNumber:`+1666${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(registered.status()).toBe(200);const user=await registered.json();
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
 for(const route of ['/dashboard','/relationship-tree','/following','/feed','/contacts','/messages','/circles','/circle-search','/discover','/timeline','/finance','/health','/trust','/profile','/privacy','/settings','/session','/notifications','/reports','/help','/ai-activity',`/people/${user.id}`])await review(route);
 // Only promote the freshly created, explicitly identified disposable fixture.
 const database=readFileSync('../../.tools/preview/database.txt','utf8').trim();if(!/^[a-z][a-z0-9_]*$/.test(database)||!Number.isSafeInteger(user.id))throw Error('Invalid test database or fixture');
 execFileSync('docker',['exec','myaaptha-preview-postgres-1','psql','-U','myaaptha','-d',database,'-c',`UPDATE users SET role='ADMIN' WHERE id=${user.id} AND username='${username}';`]);
 try{
  const relogin=await page.request.post('/api/web-auth/login',{headers:{'X-MyAaptha-Web':'1',Origin:'http://localhost:3000'},data:{identifier:username,password}});expect(relogin.status()).toBe(200);
  await review('/dashboard','admin-dashboard');await review('/settings','admin-settings');await review('/help','admin-help');await review('/moderation');await review('/security-reports');
 }finally{execFileSync('docker',['exec','myaaptha-preview-postgres-1','psql','-U','myaaptha','-d',database,'-c',`UPDATE users SET role='USER' WHERE id=${user.id} AND username='${username}';`]);writeFileSync(`${folder}/audit.json`,JSON.stringify(audit,null,2));await api.dispose();}
});
