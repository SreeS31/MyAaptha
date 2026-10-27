import {expect,test} from './fixtures';
import AxeBuilder from '@axe-core/playwright';
import {randomUUID} from 'node:crypto';
import {readFileSync,mkdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';

test('administrator upload-level draft has named fields and fits the viewport',async({page,playwright},info)=>{
 page.setDefaultTimeout(15000);
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`ui-admin-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
 let database='',id=0,promoted=false;
 try{
  const registered=await api.post('/api/users',{data:{username,password,phoneNumber:`+1857${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(registered.status()).toBe(200);id=(await registered.json()).id;
  database=readFileSync('../../.tools/preview/database.txt','utf8').trim();
  if(!/^[a-z][a-z0-9_]*$/.test(database)||!Number.isSafeInteger(id)||id<=0)throw Error('Invalid isolated fixture identity');
  execFileSync('docker',['exec','myaaptha-preview-postgres-1','psql','-U','myaaptha','-d',database,'-c',`UPDATE users SET role='ADMIN' WHERE id=${id} AND username='${username}';`]);promoted=true;
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/settings');const panel=page.locator('#storage');await panel.getByText('Manage user levels',{exact:true}).click();
  const name=panel.getByLabel('Name',{exact:true});
  if(await name.count()===0)await panel.getByRole('button',{name:'+ Add level',exact:true}).click();
  await expect(name.first()).toBeVisible();
  for(const field of ['Name','Storage (GB)','Per file (MB)','Maximum days'])await expect(panel.getByLabel(field,{exact:true}).first()).toBeVisible();
  const result=await new AxeBuilder({page}).withRules(['color-contrast','label','select-name','button-name','input-button-name']).analyze();expect(result.violations).toEqual([]);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true);
  mkdirSync('../../.tools/ui-forms-current/'+info.project.name,{recursive:true});await page.screenshot({path:`../../.tools/ui-forms-current/${info.project.name}/admin-upload-level-draft.png`,fullPage:true});
 }finally{
  if(promoted)execFileSync('docker',['exec','myaaptha-preview-postgres-1','psql','-U','myaaptha','-d',database,'-c',`UPDATE users SET role='USER' WHERE id=${id} AND username='${username}';`]);
  await api.dispose();
 }
});
