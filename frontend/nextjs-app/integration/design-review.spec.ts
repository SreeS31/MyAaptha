import {test as publicTest} from '@playwright/test';
import {test,expect} from './fixtures';
import AxeBuilder from '@axe-core/playwright';
import {randomUUID} from 'node:crypto';

publicTest('public pages load the compact brand asset without runtime image optimization',async({page})=>{
 const optimized:string[]=[];page.on('request',r=>{if(r.url().includes('/_next/image?'))optimized.push(r.url());});
 for(const path of ['/','/auth']){
  await page.goto(path);await expect(page).toHaveTitle('MyAaptha');
  const logo=page.locator('img[src="/myaaptha-logo-256.webp"]');await expect(logo).toBeVisible();
  await expect.poll(()=>logo.evaluate((image:HTMLImageElement)=>image.complete&&image.naturalWidth>0)).toBe(true);
 }
 expect(optimized).toEqual([]);
});

publicTest('launch board defaults to current evidence and preserves older saved plans',async({page,request})=>{
 const url='http://127.0.0.1:4317/docs/launch-board/';
 const source=await (await request.get(url+'launch-data.json')).json();
 const old=structuredClone(source),referenced=new Set(old.modules.flatMap((m:any)=>m.tasks.flatMap((t:any)=>t.depends)));
 const leaf=old.modules.flatMap((m:any)=>m.tasks).find((t:any)=>!referenced.has(t.id));
 for(const m of old.modules)m.tasks=m.tasks.filter((t:any)=>t.id!==leaf.id);
 old.baselineRevision='older-browser-plan';
 await page.addInitScript(value=>localStorage.setItem('myaaptha-launch-board-v1',JSON.stringify(value)),old);
 await page.goto(url+'index.html');
 const total=source.modules.reduce((n:number,m:any)=>n+m.tasks.length,0);
 const displayed=page.locator('.stat').filter({hasText:'Subtasks'}).locator('b');
 await expect(page.locator('#planSource')).toHaveValue('source');await expect(displayed).toHaveText(String(total));
 await expect(page.locator('.readiness-details')).not.toHaveAttribute('open','');
 await page.locator('#planSource').selectOption('saved');await expect(displayed).toHaveText(String(total-1));
 await page.locator('#planSource').selectOption('source');await expect(displayed).toHaveText(String(total));
 expect(await page.evaluate(()=>JSON.parse(localStorage.getItem('myaaptha-launch-board-v1')!).baselineRevision)).toBe('older-browser-plan');
 await page.locator('#boardTab').focus();await page.keyboard.press('ArrowRight');await expect(page.locator('#statusTab')).toBeFocused();await expect(page.locator('#statusView')).toBeVisible();
 await page.keyboard.press('Home');await expect(page.locator('#boardTab')).toBeFocused();await expect(page.locator('#boardView')).toBeVisible();
 const audit=await new AxeBuilder({page}).withRules(['color-contrast','label','select-name','button-name']).analyze();expect(audit.violations).toEqual([]);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});

test('narrow pages, larger browser text and settings save stay usable',async({page,playwright})=>{
 test.setTimeout(300000);
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'}),username=`design-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1847${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  await page.goto('/auth');await expect(page.getByAltText('MyAaptha logo',{exact:true})).toHaveAttribute('src','/myaaptha-logo-256.webp');await expect.poll(()=>page.getByAltText('MyAaptha logo',{exact:true}).evaluate((image:HTMLImageElement)=>image.complete&&image.naturalWidth>0)).toBe(true);await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/,{timeout:15000});
  await page.setViewportSize({width:320,height:800});
  for(const path of ['/dashboard','/profile','/settings','/finance','/health','/messages','/online-feed','/relationship-tree']){
   await page.goto(path);await page.locator('main').first().waitFor();await expect(page.locator('main').getByText(/^Loading(?:\b|…|\.{3})/)).toHaveCount(0);
   expect(await page.evaluate(()=>getComputedStyle(document.documentElement).fontSize)).toBe('16px');
   await page.addStyleTag({content:'html{font-size:125%!important}'});await page.evaluate(()=>document.fonts.ready);
   expect.soft(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),path+' narrow reflow').toBe(true);
   const search=await page.getByRole('searchbox',{name:'Search MyAaptha'}).boundingBox(),bar=await page.locator('.workspace-topbar').boundingBox(),filters=await page.getByRole('button',{name:'Open search filters'}).boundingBox();
   expect(search!.width,path+' usable search width').toBeGreaterThanOrEqual(120);expect(filters!.y,path+' search button stays in header').toBeGreaterThanOrEqual(bar!.y);expect(filters!.y+filters!.height,path+' search button stays in header').toBeLessThanOrEqual(bar!.y+bar!.height+1);
   const axe=await new AxeBuilder({page}).withRules(['color-contrast','label','select-name','button-name']).analyze();expect.soft(axe.violations,path).toEqual([]);
   if(path==='/settings'){
    const save=page.getByRole('button',{name:'Save settings',exact:true});await save.scrollIntoViewIfNeeded();
    expect(await save.locator('..').evaluate(node=>getComputedStyle(node).position)).toBe('static');
    await save.click();await expect(save.locator('..').getByRole('status')).toContainText(/saved/i);
   }
  }
 }finally{await api.dispose();}
});
