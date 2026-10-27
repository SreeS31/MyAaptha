import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';
import AxeBuilder from '@axe-core/playwright';

test('organizer OAuth readiness, terminal errors, empty results and cancellation',async({page,context,playwright})=>{
  test.setTimeout(180000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`oauth-ui-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1874${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  let available=false,lookupFails=false,starts=0,reads=0,mode='denied';
  let releaseStart:(()=>void)|undefined;
  await context.route('**/api/address-book/providers',async route=>{
    await route.fulfill({status:lookupFails?503:200,contentType:'application/json',body:JSON.stringify(lookupFails?{message:'Unavailable'}:{google:available,microsoft:false})});
  });
  await context.route('**/oauth/provider-fixture',route=>route.fulfill({contentType:'text/html',body:'<p>Synthetic consent window; no provider connected.</p>'}));
  await page.route('**/api/contact-organizer/oauth/start',async route=>{
    starts++;
    if(mode==='held-start')await new Promise<void>(resolve=>releaseStart=resolve);
    await route.fulfill({contentType:'application/json',body:JSON.stringify({authorizationUrl:'http://localhost:3000/oauth/provider-fixture',provider:'google',resultKey:'synthetic-key'})});
  });
  await page.route('**/api/contact-organizer/oauth/results/synthetic-key',async route=>{
    reads++;
    if(mode==='pending')return route.fulfill({status:404,contentType:'application/json',body:'{"message":"Pending"}'});
    if(mode==='denied')return route.fulfill({status:422,contentType:'application/json',body:'{"message":"Contact access was cancelled or denied. Nothing was imported."}'});
    if(mode==='forbidden')return route.fulfill({status:403,contentType:'application/json',body:'{"message":"Access denied"}'});
    if(mode==='legacy-failure')return route.fulfill({contentType:'application/json',body:'{"status":"failed","message":"Legacy provider failure"}'});
    if(mode==='empty')return route.fulfill({contentType:'application/json',body:'[]'});
    return route.fulfill({contentType:'application/json',body:JSON.stringify([{contact_key:'allowed',display_name:'Synthetic suggestion',phone:'+15551234567',email:null,suggested_relationship:'Other',suggested_circles:[],confidence:.5,reasons:['Synthetic fixture']}])});
  });
  try{
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    const organizer=page.locator('.contact-organizer');
    const open=async()=>{await organizer.getByRole('button',{name:'Import contacts',exact:true}).click();await organizer.getByRole('checkbox',{name:/Allow this one-time analysis/}).check();await organizer.getByRole('textbox',{name:'Email address containing the contacts'}).fill('fixture@example.test');};
    const google=organizer.getByRole('button',{name:'Connect Google Contacts',exact:true});
    await open();await expect(google).toBeDisabled();await expect(organizer.getByText('Email contact providers are not available yet. You can import a file below.')).toBeVisible();expect(starts).toBe(0);

    // Readiness lookup failures can be retried independently of file import.
    lookupFails=true;await page.reload();await open();await expect(organizer.getByRole('button',{name:'Retry providers'})).toBeVisible();available=true;lookupFails=false;
    await organizer.getByRole('button',{name:'Retry providers'}).click();await expect(google).toBeEnabled();
    // Blocked popups must not allocate an OAuth attempt on the API.
    await page.evaluate(()=>{window.open=()=>null;});await google.click();await expect(organizer.getByRole('alert')).toContainText('Allow pop-ups');expect(starts).toBe(0);
    await page.reload();await open();await expect(google).toBeEnabled();

    for(const scenario of ['denied','forbidden','legacy-failure','empty']){
      mode=scenario;const previousReads=reads;await google.click();
      if(scenario==='empty')await expect(organizer.getByText('No contacts were found in this account. Nothing was saved.')).toBeVisible();
      else await expect(organizer.getByRole('alert')).toContainText(scenario==='denied'?'cancelled or denied':scenario==='forbidden'?'Access denied':'Legacy provider failure');
      expect(reads).toBe(previousReads+1);await expect(google).toBeEnabled();
    }
    mode='pending';await google.click();await expect.poll(()=>reads).toBeGreaterThan(4);
    const beforeCancel=reads;await organizer.getByRole('button',{name:'Cancel connection',exact:true}).click();await page.waitForTimeout(2300);expect(reads).toBe(beforeCancel);await expect(google).toBeEnabled();

    // A late start response after cancel cannot open a provider or restart polling.
    mode='held-start';await google.click();await expect.poll(()=>Boolean(releaseStart)).toBe(true);
    const beforeHeldCancel=reads;await organizer.getByRole('button',{name:'Cancel connection',exact:true}).click();releaseStart!();await page.waitForTimeout(2300);expect(reads).toBe(beforeHeldCancel);await expect(google).toBeEnabled();

    mode='success';await google.click();await expect(organizer.getByText('1 contacts analyzed. Review every suggestion before confirming.')).toBeVisible();
    await expect(organizer.getByRole('button',{name:'Confirm selected contacts',exact:true})).toBeEnabled();
    await google.hover();
    const hoverAccessibility=await new AxeBuilder({page}).include('.contact-organizer').withRules(['color-contrast','button-name','label']).analyze();
    expect(hoverAccessibility.violations).toEqual([]);
    await organizer.getByRole('heading',{name:'Import an address book',exact:true}).hover();await google.focus();
    const focusAccessibility=await new AxeBuilder({page}).include('.contact-organizer').withRules(['color-contrast','button-name','label']).analyze();
    expect(focusAccessibility.violations).toEqual([]);
    const login=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(login.status()).toBe(200);
    const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
    const providerPolicy=await (await api.get('/api/address-book/providers',{headers})).json();
    expect(Object.keys(providerPolicy).sort()).toEqual(['google','microsoft']);
    expect(Object.values(providerPolicy).every(value=>typeof value==='boolean')).toBe(true);
    expect(await (await api.get('/api/network/relationships',{headers})).json()).toEqual([]);
    expect((await (await api.get('/api/address-book',{headers})).json()).total).toBe(0);
    expect((await api.get('/api/contact-organizer/oauth/results/missing-fixture',{headers})).status()).toBe(404);
  }finally{releaseStart?.();await api.dispose();}
});
