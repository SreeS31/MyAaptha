import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('manual draft survives failed save and retries multiple measurements without duplicate submission',async({page,playwright})=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`entry-${randomUUID().slice(0,8)}`,password=`Secret-${randomUUID()}`;let release:(()=>void)|undefined;
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1882${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/health');await page.getByRole('button',{name:'Enter manually',exact:true}).click();await page.getByLabel('Report name',{exact:true}).fill('Synthetic retry report');await page.getByLabel('Collection date',{exact:true}).fill('2026-10-01');await page.getByLabel('Notes',{exact:true}).fill('Synthetic retained notes');
  await page.getByLabel('Metric',{exact:true}).fill('Synthetic zero');await page.getByLabel('Value',{exact:true}).fill('0');await page.getByLabel('Unit',{exact:true}).fill('u');await page.getByRole('button',{name:/Add measurement/}).click();
  await page.getByLabel('Metric',{exact:true}).nth(1).fill('Synthetic second');await page.getByLabel('Value',{exact:true}).nth(1).fill('12.5');await page.getByLabel('Unit',{exact:true}).nth(1).fill('v');await page.getByLabel('Reference minimum',{exact:true}).nth(1).fill('20');await page.getByLabel('Reference maximum',{exact:true}).nth(1).fill('10');
  let attempts=0;
  await page.route('**/api/health/reports',async route=>{attempts++;if(attempts===1){await new Promise<void>(resolve=>{release=resolve;});await route.fulfill({status:503,json:{message:'Synthetic save unavailable. Retry.'}});}else await route.continue();});
  await page.getByRole('button',{name:'Save report and measurements',exact:true}).click();await expect(page.locator('main.health-page').getByRole('alert')).toContainText('Reference minimum cannot exceed maximum');expect(attempts).toBe(0);
  await page.getByLabel('Reference minimum',{exact:true}).nth(1).fill('10');await page.getByLabel('Reference maximum',{exact:true}).nth(1).fill('20');await page.getByRole('button',{name:'Save report and measurements',exact:true}).click();
  await expect(page.getByRole('button',{name:'Saving...',exact:true})).toBeDisabled();await expect(page.getByLabel('Notes',{exact:true})).toBeDisabled();await expect(page.getByRole('button',{name:'Close manual entry',exact:true})).toBeDisabled();await expect.poll(()=>typeof release).toBe('function');release!();
  await expect(page.locator('main.health-page').getByRole('alert')).toContainText('Synthetic save unavailable');await expect(page.locator('main.health-page').getByRole('alert')).toBeInViewport();await expect(page.getByLabel('Report name',{exact:true})).toHaveValue('Synthetic retry report');await expect(page.getByLabel('Value',{exact:true}).nth(1)).toHaveValue('12.5');await expect(page.getByLabel('Notes',{exact:true})).toHaveValue('Synthetic retained notes');
  await page.getByRole('button',{name:'Save report and measurements',exact:true}).click();await expect(page.getByRole('heading',{name:'Synthetic retry report',exact:true})).toBeVisible();expect(attempts).toBe(2);
  const response=await api.get('/api/health/dashboard',{headers});expect(response.status()).toBe(200);const reports=(await response.json()).reports;expect(reports).toHaveLength(1);expect(reports[0].measurements).toHaveLength(2);expect(reports[0].measurements[0].value).toBe(0);expect(reports[0].notes).toBe('Synthetic retained notes');expect(reports[0].collectedOn).toBe('2026-10-01');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.getByRole('button',{name:'Delete report record',exact:true}).click();await expect(page.getByRole('heading',{name:'Synthetic retry report',exact:true})).toHaveCount(0);
 }finally{release?.();await api.dispose();}
});
