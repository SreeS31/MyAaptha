import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('UTC midnight transactions belong to one month in both cookie and bearer sessions',async({page,playwright})=>{
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`month-${randomUUID().slice(0,8)}`,password=`Secret-${randomUUID()}`;
  try{
    expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1887${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
    const auth=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(auth.status()).toBe(200);
    const headers={Authorization:`Bearer ${(await auth.json()).accessToken}`};
    for(const [merchant,occurredAt,amount] of [['Before midnight','2026-08-31T23:59:59Z',10],['At midnight','2026-09-01T00:00:00Z',20],['Next month midnight','2026-10-01T00:00:00Z',30]] as const){const response=await api.post('/api/finance/transactions',{headers,data:{merchant,occurredAt,amount,direction:'EXPENSE',category:'OTHER',source:'MANUAL'}});expect(response.status(),await response.text()).toBe(200);}
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    for(const [month,expected] of [['2026-08',10],['2026-09',20],['2026-10',30]] as const){
      const direct=await api.get(`/api/finance/summary?month=${month}`,{headers}),web=await page.request.get(`/api/finance/summary?month=${month}`);
      expect(direct.status()).toBe(200);expect(web.status()).toBe(200);expect(await web.json()).toEqual(await direct.json());expect((await direct.json()).spending).toBe(expected);
    }
    const policy=await api.get('/api/auth/security-policy');expect(policy.status()).toBe(200);const security=await policy.json();expect(typeof security.phoneVerificationRequired).toBe('boolean');expect(typeof security.phoneVerificationConfigured).toBe('boolean');
    await page.goto('/finance');await page.getByLabel('Month',{exact:true}).fill('2026-08');await expect(page.getByText('Before midnight',{exact:true})).toBeVisible({timeout:15000});await expect(page.getByText('At midnight',{exact:true})).toHaveCount(0);
    await page.getByLabel('Month',{exact:true}).fill('2026-09');await expect(page.getByText('At midnight',{exact:true})).toBeVisible();await expect(page.getByText('Before midnight',{exact:true})).toHaveCount(0);await expect(page.getByText('Next month midnight',{exact:true})).toHaveCount(0);
  }finally{await api.dispose();}
});
