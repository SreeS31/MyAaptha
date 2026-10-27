import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';

test('shared compact layout keeps workspace pages within the viewport',async({page,playwright},info)=>{
 test.setTimeout(600000);page.setDefaultTimeout(15000);
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'}),username=`density-${randomUUID().slice(0,8)}`,password=`Density-${randomUUID()}`;
 const results:Array<{path:string;overflow:boolean;headingHeight:number;fields:number}>=[];
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1882${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  const paths=['/dashboard','/relationship-tree','/feed','/health','/finance','/career','/interests','/messages','/online-feed','/profile','/settings','/timeline','/trust','/contacts','/circles','/following','/notifications','/session','/workspace-tools','/menu-comparison','/circle-search','/discover','/help','/privacy','/reports','/ai-activity','/moderation','/security-reports'];
  const folder=`../../.tools/compact-workspace/${info.project.name}`;mkdirSync(folder,{recursive:true});
  for(const path of paths){
   const response=await page.goto(path);expect(response?.status(),path).toBe(200);await expect(page.locator('main').first()).toBeVisible();
   await expect(page.locator('main').getByText(/^Loading(?:\b|…|\.{3})/)).toHaveCount(0,{timeout:15000});
   await page.evaluate(async()=>{await document.fonts.ready;await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});
   await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),{message:`${path}: horizontal overflow`}).toBe(false);
   const result=await page.evaluate(path=>{const header=document.querySelector('main>header,main>.page-heading');return {path,overflow:document.documentElement.scrollWidth>innerWidth+1,headingHeight:header?.getBoundingClientRect().height||0,fields:document.querySelectorAll('main input,main select,main textarea').length};},path);results.push(result);
   if(['/dashboard','/health','/finance','/profile','/settings','/online-feed'].includes(path))await page.screenshot({path:`${folder}/${path.slice(1)}.png`});
  }
  writeFileSync(`${folder}/audit.json`,JSON.stringify(results,null,2));
 }finally{await api.dispose();}
});
