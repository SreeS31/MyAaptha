import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';

// UI contracts are mocked to avoid paid provider calls. Authorization/cache behavior
// is exercised against the database in HelpAnswerMemoryTest.
test('admin gate, explicit stronger retry and public-answer review',async({page,request})=>{
  const username=`help-ui-${randomUUID().slice(0,10)}`,password=`Help-${randomUUID()}`;
  expect((await request.post('http://127.0.0.1:8080/api/users',{data:{username,password,phoneNumber:`+1997${Date.now().toString().slice(-10)}`}})).ok()).toBeTruthy();
  await page.goto('/auth');
  await page.getByLabel('Username or mobile number',{exact:true}).fill(username);
  await page.getByLabel('Password',{exact:true}).fill(password);
  await page.getByRole('button',{name:'Continue',exact:true}).click();
  await expect(page).toHaveURL(/dashboard/);
  let enhanced=false, calls=0, published=false, cleared=false;
  await page.route('**/api/ai/help',route=>route.fulfill({json:{aiConfigured:true,enhancedEnabled:enhanced,canManage:true,baseModel:'gpt-4.1-mini',enhancedModel:'gpt-4.1',questions:[]}}));
  await page.route('**/api/ai/help/admin/settings',async route=>{enhanced=route.request().postDataJSON().enhancedEnabled;await route.fulfill({json:{enhancedEnabled:enhanced}});});
  await page.route('**/api/ai/help/chat',async route=>{
    calls++;const retry=route.request().postDataJSON().retryOf;
    if(retry)expect(retry).toBe('base-id');
    await route.fulfill({json:{answer:retry?'A more detailed answer.':'MyAaptha is free for all users.',mode:retry?'AI':'CACHE',notice:retry?'':'Saved answer. No AI credits used.',exchangeId:retry?'strong-id':'base-id',tier:retry?'ENHANCED':'BASE',model:retry?'gpt-4.1':'gpt-4.1-mini',sources:[{id:'pricing',title:'Pricing',path:'/help',content:'MyAaptha is free for all users.'}]}});
  });
  await page.route('**/api/ai/help/admin/answers',async route=>{const body=route.request().postDataJSON();expect(body.confirmedPublic).toBe(true);expect(body.question).toBe('Is MyAaptha free?');published=true;await route.fulfill({status:200,body:''});});
  await page.route('**/api/ai/help/history',async route=>{expect(route.request().method()).toBe('DELETE');cleared=true;await route.fulfill({status:200,body:''});});
  await page.goto('/help');
  await page.getByLabel('Your question',{exact:true}).fill('Is MyAaptha free?');
  await page.getByRole('button',{name:'Ask',exact:true}).click();
  await expect(page.getByRole('log')).toContainText('No AI credits used');
  await expect(page.getByRole('button',{name:'Not satisfied? Try stronger model'})).toHaveCount(0);
  await page.getByText('Administrator: AI cost controls',{exact:true}).click();
  await page.getByLabel('Allow users to try a stronger model').click();
  await expect(page.getByLabel('Allow users to try a stronger model')).toBeChecked();
  await expect(page.getByRole('button',{name:'Not satisfied? Try stronger model'})).toBeVisible();
  expect(calls).toBe(1);
  await page.getByRole('button',{name:'Not satisfied? Try stronger model'}).click();
  await expect(page.getByRole('log')).toContainText('A more detailed answer');expect(calls).toBe(2);
  await page.getByRole('button',{name:'Review for shared answers'}).first().click();
  await expect(page.getByRole('button',{name:'Publish shared answer'})).toBeDisabled();
  await page.getByLabel('I verified this answer is correct and contains no private information.').check();
  await page.getByRole('button',{name:'Publish shared answer'}).click();
  await expect(page.getByRole('heading',{name:'Review a public help answer'})).toHaveCount(0);expect(published).toBe(true);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
  await page.screenshot({path:`../../.tools/preview/help-memory-${test.info().project.name}.png`,fullPage:true});
  await page.getByRole('button',{name:'Clear chat'}).click();
  await expect(page.getByRole('log')).not.toContainText('free for all users');expect(cleared).toBe(true);
});
