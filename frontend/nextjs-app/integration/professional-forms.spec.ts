import {expect,test} from './fixtures';
import AxeBuilder from '@axe-core/playwright';
import {randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';

test('expanded forms, upload access and workspace keyboard navigation',async({page,playwright},info)=>{
 test.setTimeout(600000);page.setDefaultTimeout(15000);
 const folder=`../../.tools/ui-forms-current/${info.project.name}`;mkdirSync(folder,{recursive:true});
 const findings:any[]=[];
 const rules=['color-contrast','label','select-name','button-name','input-button-name','aria-input-field-name'];
 async function audit(name:string){
  await page.evaluate(()=>document.fonts.ready);
  const result=await new AxeBuilder({page}).withRules(rules).analyze();
  findings.push({name,path:new URL(page.url()).pathname,violations:result.violations,fields:await page.locator('main input,main select,main textarea').count()});
  writeFileSync(`${folder}/audit.json`,JSON.stringify(findings,null,2));
  expect.soft(result.violations,name).toEqual([]);
  expect.soft(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),`${name}: overflow`).toBe(true);
  await page.screenshot({path:`${folder}/${name}.png`,fullPage:true});
 }
 await page.goto('/auth');await page.getByRole('button',{name:'New to MyAaptha? Create an account'}).click();
 await expect(page.getByLabel('First name',{exact:true})).toBeVisible();await audit('registration');
 await page.getByRole('button',{name:'Create account',exact:true}).click();
 expect(await page.locator('.registration-form').evaluate((form:HTMLFormElement)=>form.checkValidity())).toBe(false);
 await page.goto('/recover-account');await audit('recovery');
 await page.goto('/verify-phone');await audit('phone-verification');
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`forms-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1837${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  const menu=page.getByRole('button',{name:'Toggle main menu'});
  if(info.project.name==='mobile-web'){
   await expect(menu).toHaveAttribute('aria-expanded','false');await menu.click();await expect(menu).toHaveAttribute('aria-expanded','true');
   const first=page.locator('#workspace-navigation a').first(),last=page.locator('#workspace-navigation button').last();
   await expect(first).toBeFocused();await page.keyboard.press('Shift+Tab');await expect(last).toBeFocused();await page.keyboard.press('Tab');await expect(first).toBeFocused();
   await page.keyboard.press('Escape');await expect(menu).toHaveAttribute('aria-expanded','false');await expect(menu).toBeFocused();await expect(page.locator('#workspace-navigation')).toHaveAttribute('inert','');
  }
  await page.getByRole('link',{name:'Skip to content'}).focus();await page.keyboard.press('Enter');await expect(page.locator('#workspace-main')).toBeFocused();
  await page.goto('/profile');
  for(const title of ['Personal details','Address','Communication & social media','Education','Employment']){
   const region=page.getByRole('region',{name:title,exact:true});await region.getByRole('button',{name:`Edit ${title}`,exact:true}).click();
   await expect(region.locator('form')).toBeVisible();await audit(`profile-${title.split(' ')[0].toLowerCase()}`);
   await region.getByRole('button',{name:'Cancel',exact:true}).click();await expect(region.locator('form')).toHaveCount(0);
  }
  const gallery=page.getByLabel('Upload gallery photos',{exact:true});await gallery.focus();await expect(gallery).toBeFocused();
  await page.getByRole('button',{name:'Edit profile photo',exact:true}).click();const photo=page.getByLabel('Upload profile photo',{exact:true});await photo.focus();await expect(photo).toBeFocused();await audit('profile-photo');
  await page.goto('/timeline');await page.getByRole('button',{name:'Add event',exact:true}).click();await expect(page.getByRole('dialog',{name:'Add event',exact:true})).toBeVisible();await audit('timeline-editor');await page.keyboard.press('Escape');await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.goto('/circles');await page.getByRole('button',{name:'Create circle',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Create circle',exact:true});await expect(dialog.getByLabel('Circle name',{exact:true})).toBeFocused();await audit('circle-editor');await dialog.getByRole('button',{name:'Create circle',exact:true}).click();expect(await dialog.locator('form').evaluate((form:HTMLFormElement)=>form.checkValidity())).toBe(false);await page.keyboard.press('Escape');
  await page.goto('/health');await page.getByRole('button',{name:'Enter manually',exact:true}).click();await expect(page.getByLabel('Report name',{exact:true})).toBeVisible();await page.getByRole('button',{name:/Add measurement/}).click();await audit('health-multiple-measurements');
  for(const route of ['/finance','/contacts','/messages','/feed','/trust','/privacy','/settings','/notifications','/reports','/help','/ai-activity','/relationship-tree']){
   await page.goto(route);await page.locator('main').first().waitFor();
   await page.locator('main details').evaluateAll(nodes=>nodes.forEach(node=>{(node as HTMLDetailsElement).open=true;}));
   await audit(`expanded-${route.slice(1)}`);
   if(route==='/feed'){const attachment=page.getByLabel('Attach a diary memory',{exact:true});await attachment.focus();await expect(attachment).toBeFocused();}
   if(route==='/finance'){await page.getByRole('button',{name:'Paste SMS',exact:true}).click();await audit('finance-sms');}
   if(route==='/relationship-tree'){const panel=page.locator('#add-network-person');await panel.waitFor();if(!await panel.evaluate((node:HTMLDetailsElement)=>node.open))await panel.locator(':scope>summary').click();await page.locator('.country-code-select').evaluateAll(nodes=>nodes.forEach(node=>{(node as HTMLDetailsElement).open=false;}));await page.getByRole('radio',{name:'Managed person',exact:true}).check();await audit('managed-person');await page.getByLabel('This person is deceased',{exact:true}).check();await audit('managed-person-deceased');}
  }
 }finally{await api.dispose();}
});
