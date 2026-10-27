import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';
import AxeBuilder from '@axe-core/playwright';

test.use({actionTimeout:15000});

test('finance overview supports a compact start, renewal shortcuts and clear transaction activity',async({page,playwright},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'}),username=`finance-ui-${randomUUID().slice(0,8)}`,password=`Finance-${randomUUID()}`;
 let headers:Record<string,string>={};const renewalIds:number[]=[],transactionIds:number[]=[];const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1882${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);
  const auth=await(await api.post('/api/auth/login',{data:{identifier:username,password}})).json();headers={Authorization:`Bearer ${auth.accessToken}`};
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/finance');const overview=page.getByRole('region',{name:'Monthly overview',exact:true}),renewals=page.getByRole('region',{name:/^Bills & warranties/});
  await expect(overview).toHaveAttribute('aria-busy','false');await expect(renewals).toHaveAttribute('aria-busy','false');
  expect((await overview.boundingBox())!.y).toBeLessThan((await renewals.boundingBox())!.y);
  await expect(renewals.getByRole('searchbox')).toHaveCount(0);
  await page.screenshot({path:`../../.tools/preview/finance-polish-empty-${info.project.name}.png`});
  await renewals.getByRole('button',{name:'Add warranty',exact:true}).click();const editor=page.getByRole('dialog',{name:'Add bill or warranty',exact:true});await expect(editor.getByRole('combobox',{name:'Item type',exact:true})).toHaveValue('WARRANTY');await editor.getByRole('button',{name:'Cancel',exact:true}).click();
  const after=(days:number)=>{const date=new Date();date.setUTCDate(date.getUTCDate()+days);return date.toISOString().slice(0,10);};
  for(const [title,kind,expiresOn,amount] of [['Internet plan','BILL',after(7),899],['Headphones cover','WARRANTY',after(-2),2499]] as const){const response=await api.post('/api/finance/renewals',{headers,data:{kind,title,provider:'Example service',expiresOn,timezone:'UTC',amount,remindersEnabled:false,archived:false}});expect(response.status()).toBe(201);renewalIds.push((await response.json()).id);}
  await page.reload();await expect(renewals.getByRole('article')).toHaveCount(2);await renewals.getByRole('button',{name:/Due within 30 days/}).click();await expect(renewals.getByRole('article')).toHaveCount(1);await expect(renewals.getByRole('article',{name:'Internet plan',exact:true})).toBeVisible();await renewals.getByRole('button',{name:/Expired items/}).click();await expect(renewals.getByRole('article',{name:'Headphones cover',exact:true})).toBeVisible();await renewals.getByRole('combobox',{name:'Show',exact:true}).selectOption('active');
  await page.getByLabel('Month',{exact:true}).fill('2026-10');await expect(overview).toHaveAttribute('aria-busy','false');
  await page.getByRole('button',{name:'Add transaction',exact:true}).click();const entry=page.locator('#finance-entry');await expect(entry).toHaveAttribute('open','');
  for(const [merchant,amount,direction,category] of [['Monthly income','12500','INCOME','OTHER'],['Weekly groceries','1850','EXPENSE','GROCERIES']] as const){await entry.getByLabel('Amount',{exact:true}).fill(amount);await entry.getByRole('combobox',{name:'Type',exact:true}).selectOption(direction);await entry.getByRole('combobox',{name:'Category',exact:true}).selectOption(category);await entry.getByLabel('Merchant',{exact:true}).fill(merchant);await entry.getByLabel('Date',{exact:true}).fill('2026-10-15T12:00');await entry.getByRole('button',{name:'Save transaction',exact:true}).click();await expect(page.getByRole('article',{name:merchant,exact:true})).toBeVisible();}
  const summary=await(await api.get('/api/finance/summary?month=2026-10',{headers})).json();transactionIds.push(...summary.transactions.map((item:{id:number})=>item.id));expect(summary.income).toBe(12500);expect(summary.spending).toBe(1850);expect(summary.net).toBe(10650);
  await entry.getByRole('button',{name:'Paste SMS',exact:true}).click();await expect(entry.getByLabel('Transaction SMS',{exact:true})).toBeVisible();await entry.getByRole('button',{name:'Close',exact:true}).click();
  const filters=page.getByRole('navigation',{name:'Transaction filters'});await filters.getByRole('button',{name:'Income',exact:true}).click();await expect(page.getByRole('article',{name:'Monthly income',exact:true})).toBeVisible();await expect(page.getByRole('article',{name:'Weekly groceries',exact:true})).toHaveCount(0);await filters.getByRole('button',{name:'All',exact:true}).click();
  await page.getByRole('searchbox',{name:'Search transactions',exact:true}).fill('groceries');await expect(page.getByRole('article',{name:'Monthly income',exact:true})).toHaveCount(0);await expect(page.getByRole('article',{name:'Weekly groceries',exact:true})).toBeVisible();await page.getByRole('searchbox',{name:'Search transactions',exact:true}).fill('');
  await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:`../../.tools/preview/finance-polish-filled-${info.project.name}.png`,fullPage:true});
  const a11y=await new AxeBuilder({page}).include('.finance-page').withRules(['color-contrast','button-name','label','aria-valid-attr-value']).analyze();expect(a11y.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>n.target)}))).toEqual([]);
  const expense=page.getByRole('article',{name:'Weekly groceries',exact:true});await expense.getByRole('button',{name:'Delete transaction',exact:true}).click();const confirmation=page.getByRole('dialog',{name:'Delete transaction?',exact:true});await confirmation.getByRole('button',{name:'Cancel',exact:true}).click();await expect(expense).toBeVisible();await expense.getByRole('button',{name:'Delete transaction',exact:true}).click();await confirmation.getByRole('button',{name:'Delete transaction',exact:true}).click();await expect(expense).toHaveCount(0);
  expect((await(await api.get('/api/finance/summary?month=2026-10',{headers})).json()).spending).toBe(0);expect(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)).toBe(false);expect(errors).toEqual([]);
 }finally{for(const id of renewalIds)await api.delete(`/api/finance/renewals/${id}`,{headers});for(const id of transactionIds)await api.delete(`/api/finance/transactions/${id}`,{headers});await api.dispose();}
});
