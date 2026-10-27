import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('manual health reports share validation across browser cookies and bearer sessions',async({page,playwright})=>{
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`health-${randomUUID().slice(0,8)}`,password=`Secret-${randomUUID()}`;
  try{
    expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1886${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
    const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);
    const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await page.goto('/health');await page.getByRole('button',{name:'Enter manually',exact:true}).click();
    await page.getByLabel('Report name',{exact:true}).fill('Synthetic browser report');await page.getByLabel('Collection date',{exact:true}).fill('2026-10-01');
    await page.getByLabel('Metric',{exact:true}).fill('Synthetic marker');await page.getByLabel('Value',{exact:true}).fill('10');await page.getByLabel('Unit',{exact:true}).fill('u');
    await page.getByRole('button',{name:'Save report and measurements',exact:true}).click();await expect(page.getByRole('heading',{name:'Synthetic browser report',exact:true})).toBeVisible();
    const valid={reportName:'Synthetic invalid fixture',collectedOn:'2026-10-01',measurements:[{metricName:'Synthetic marker',value:1,unit:'u'}]};
    const webHeaders={Origin:new URL(page.url()).origin,'X-MyAaptha-Web':'1'};
    expect((await page.request.post('/api/health/reports',{data:valid})).status()).toBe(403);
    for(const invalid of [{...valid,collectedOn:'2099-01-01'},{...valid,measurements:[]},{...valid,measurements:[null]}]){
      expect((await api.post('/api/health/reports',{headers,data:invalid})).status()).toBe(400);
      const rejected=await page.request.post('/api/health/reports',{headers:webHeaders,data:invalid});
      expect(rejected.status()).toBe(400);expect((await rejected.json()).message).not.toContain('2099-01-01');
    }
    const direct=await api.get('/api/health/dashboard',{headers}),web=await page.request.get('/api/health/dashboard');expect(direct.status()).toBe(200);expect(web.status()).toBe(200);
    expect(await web.json()).toEqual(await direct.json());expect((await direct.json()).reports).toHaveLength(1);
    await page.getByRole('button',{name:'Delete report record',exact:true}).click();await expect(page.getByRole('heading',{name:'Synthetic browser report',exact:true})).toHaveCount(0);
  }finally{await api.dispose();}
});
