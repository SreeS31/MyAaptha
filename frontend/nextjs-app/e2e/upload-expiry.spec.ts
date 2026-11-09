import {test,expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('upload expiry choices reach the API, including Never and ten years',async({page})=>{
 const choices=[1,7,30,60,90,180,365,730,1095,1825,3650,0];
 const sent:number[]=[];
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;
  if(path.endsWith('/attachment')&&route.request().method()==='POST'){
   const match=route.request().postDataBuffer()?.toString().match(/name="retentionDays"\r\n\r\n(\d+)/);
   sent.push(match?Number(match[1]):-1);await route.fulfill({json:{}});return;
  }
  const data=path==='/api/auth/me'?{id:1,username:'Expiry fixture',role:'USER'}
   :path==='/api/uploads/policy'?{level:{id:1,name:'Free',storageBytes:1073741824,uploadBytes:26214400,maxRetentionDays:3650,allowNever:true},usedBytes:0,retentionDaysOptions:choices,defaultRetentionDays:0}
   :path==='/api/finance/renewals'&&route.request().method()==='POST'?{id:1}
   :path==='/api/finance/summary'?{income:0,spending:0,net:0,categories:{},transactions:[],suggestions:[]}
   :path.includes('unread')?{count:0}:[];
  await route.fulfill({json:data});
 });
 await page.goto('/finance');
 for(const days of [0,7,3650]){
  await page.getByRole('button',{name:'+ Add bill or warranty',exact:true}).click();
  const editor=page.getByRole('dialog',{name:'Add bill or warranty',exact:true});
  await editor.getByLabel('Title',{exact:true}).fill('Expiry fixture');
  await editor.getByLabel('Due date',{exact:true}).fill('2027-12-31');
  await editor.getByLabel('Receipt (optional)',{exact:true}).setInputFiles({name:'receipt.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.7\n1 0 obj\n<<>>\nendobj')});
  await editor.getByRole('button',{name:'Save item',exact:true}).click();
  const dialog=page.getByRole('dialog',{name:'Keep this attachment',exact:true});
  const select=dialog.getByLabel('Attachment availability');
  await expect(select).toHaveValue('0');
  await expect(select).toBeFocused();
  await expect(dialog.getByRole('status')).toContainText('stays until you delete it');
  expect(await dialog.evaluate(element=>element.getBoundingClientRect().right<=innerWidth)).toBe(true);
  expect(await select.locator('option').evaluateAll(options=>options.map(option=>(option as HTMLOptionElement).value))).toEqual(choices.map(String));
  await select.selectOption(String(days));
  await expect(dialog.getByRole('status')).toContainText(days===0?'until you delete it':'queued for deletion');
  if(days===7){
   const audit=await new AxeBuilder({page}).include('dialog[aria-labelledby="upload-lifetime-title"]').withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
   expect(audit.violations).toEqual([]);
  }
  await dialog.getByRole('button',{name:'Continue upload',exact:true}).click();
  await expect(editor).not.toBeVisible();
  expect(sent.at(-1)).toBe(days);
 }
 expect(sent).toEqual([0,7,3650]);
 await page.getByRole('button',{name:'+ Add bill or warranty',exact:true}).click();
 const editor=page.getByRole('dialog',{name:'Add bill or warranty',exact:true});
 await editor.getByLabel('Title',{exact:true}).fill('Cancelled attachment');
 await editor.getByLabel('Due date',{exact:true}).fill('2027-12-31');
 await editor.getByLabel('Receipt (optional)',{exact:true}).setInputFiles({name:'cancel.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.7\n')});
 await editor.getByRole('button',{name:'Save item',exact:true}).click();
 await expect(page.getByRole('dialog',{name:'Keep this attachment',exact:true})).toBeVisible();
 await page.keyboard.press('Escape');
 await expect(page.getByRole('dialog',{name:'Keep this attachment',exact:true})).not.toBeVisible();
 await expect(editor).toContainText('Upload cancelled.');
 expect(sent).toEqual([0,7,3650]);
});
