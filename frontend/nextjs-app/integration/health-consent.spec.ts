import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('health processing stays disabled by default and UI consent applies to one report',async({page,playwright})=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`consent-${randomUUID().slice(0,8)}`,password=`Secret-${randomUUID()}`;
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1885${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
  const policy=await api.get('/api/health/ai-status',{headers});expect(await policy.json()).toEqual({configured:false,consentRequired:true,provider:'OpenAI'});
  const rejected=await api.post('/api/health/reports/analyze',{headers,multipart:{processingConsent:'true',file:{name:'synthetic.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.4\nSynthetic consent fixture\n%%EOF')}}});expect(rejected.status()).toBe(503);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/health');await expect(page.getByRole('button',{name:'Upload report',exact:true})).toBeDisabled();await expect(page.getByRole('button',{name:'Enter manually',exact:true})).toBeEnabled();
  // Mock only the UI's enabled branch. No provider request is forwarded.
  await page.route('**/api/health/ai-status',route=>route.fulfill({json:{configured:true,consentRequired:true,provider:'OpenAI'}}));
  let uploads=0;
  await page.route('**/api/health/reports/analyze',async route=>{uploads++;const body=route.request().postData()||'';expect(body).toContain('name="processingConsent"');expect(body).toContain('true');await route.fulfill({json:{id:1}});});
  await page.reload();const consent=page.getByRole('checkbox',{name:/I consent to sending this report to OpenAI/});await expect(consent).toBeVisible();await expect(page.getByRole('button',{name:'Upload report',exact:true})).toBeDisabled();
  await consent.check();await expect(page.getByRole('button',{name:'Upload report',exact:true})).toBeEnabled();
  await page.locator('input[type="file"]').setInputFiles({name:'synthetic.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.4\nSynthetic consent fixture\n%%EOF')});
  await expect(consent).not.toBeChecked();expect(uploads).toBe(1);await expect(page.getByRole('button',{name:'Upload report',exact:true})).toBeDisabled();
 }finally{await api.dispose();}
});
