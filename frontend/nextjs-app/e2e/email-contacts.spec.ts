import {test,expect} from '@playwright/test';

test.beforeEach(async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;
  const data=path==='/api/auth/me'?{id:1,username:'Member',role:'USER'}:path==='/api/profile/me'?{photos:[]}:path==='/api/address-book/providers'?{google:false,microsoft:false}:path==='/api/address-book'?{items:[],total:0,nextCursor:null}:path.includes('unread')?{count:0}:path.includes('preferences')?{readReceipts:true}:[];
  await route.fulfill({json:data});
 });
});

test('users start provider sign-in directly without email fields or setup instructions',async({page})=>{
 let started:any;
 await page.route('**/api/address-book/oauth/start',async route=>{started=route.request().postDataJSON();await route.fulfill({status:503,json:{message:'Google Contacts is not configured yet'}});});
 await page.goto('/contacts');await page.locator('summary').filter({hasText:'Import contacts'}).click();
 const google=page.getByRole('button',{name:'Sign in with Google',exact:true});
 await expect(google).toBeEnabled();await expect(page.locator('main input[type=email]')).toHaveCount(0);
 await expect(page.getByText('Email connections need setup.',{exact:false})).toHaveCount(0);
 await google.click();await expect(page.locator('main').getByRole('alert')).toContainText('temporarily unavailable');
 expect(started).toEqual({consent:true,provider:'google',organize:true});
});

test('provider preview retains email-only contacts and small circles until reviewed save',async({page,context})=>{
 const contacts=[{displayName:'Asha INCOIS',phones:[],emails:['asha@example.test'],organization:'',groups:[]},{displayName:'Venu INCOIS',phones:[],emails:['venu@example.test'],organization:'',groups:[]},{displayName:'Cyclist',phones:[],emails:['bike@example.test'],organization:'',groups:['Cycling']}];
 let saved:any;
 await page.route('**/api/address-book/providers',route=>route.fulfill({json:{google:true,microsoft:false}}));
 await context.route('**/oauth-fixture',route=>route.fulfill({contentType:'text/html',body:'<p>Synthetic provider consent; no real mailbox accessed.</p>'}));
 await page.route('**/api/address-book/oauth/start',route=>route.fulfill({json:{provider:'google',resultKey:'fixture',authorizationUrl:'https://contact-provider.example.test/oauth-fixture'}}));
 await page.route('**/api/address-book/oauth/results/fixture',route=>route.fulfill({json:{status:'review',contacts,message:'Review contacts'}}));
 await page.route('**/api/address-book/import-reviewed',async route=>{saved=route.request().postDataJSON();await route.fulfill({json:{added:saved.contacts.length,updated:0,unchanged:0,total:saved.contacts.length,skipped:0}});});
 await page.goto('/contacts');await page.locator('summary').filter({hasText:'Import contacts'}).click();
 await page.getByRole('button',{name:'Sign in with Google',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Review contacts (3 selected)',exact:true})).toBeVisible();
 await expect(page.getByLabel('Use circle INCOIS',{exact:true})).toBeChecked();await expect(page.getByLabel('Use circle Cycling',{exact:true})).toBeChecked();
 expect(saved).toBeUndefined();
 await expect(page.getByRole('button',{name:'Import selected (3)',exact:true})).toBeDisabled();
 await page.getByRole('checkbox',{name:'I allow these contacts to be saved to my private MyAaptha address book.',exact:true}).check();
 await page.getByLabel('Use circle Cycling',{exact:true}).uncheck();
 await page.getByRole('button',{name:'Import selected (3)',exact:true}).click();
 await expect.poll(()=>saved?.contacts.length).toBe(3);
 expect(saved.contacts.every((c:any)=>c.contact.phones.length===0&&c.contact.emails.length===1)).toBe(true);
 expect(saved.contacts.find((c:any)=>c.contact.displayName==='Cyclist').circleNames).toEqual([]);
 expect(saved.contacts.find((c:any)=>c.contact.displayName==='Asha INCOIS').circleNames).toEqual(['INCOIS']);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});

test('messages uses circle wording while retaining its compatible API route',async({page})=>{
 let created:any;
 await page.route('**/api/network/chats/groups',async route=>{created=route.request().postDataJSON();await route.fulfill({json:{id:7,name:created.name,members:[],ownerName:'Member'}});});
 await page.goto('/messages');await expect(page.getByRole('button',{name:'Circles',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'New chat',exact:true}).click();await page.getByRole('button',{name:'New circle',exact:false}).click();
 await expect(page.getByRole('dialog',{name:'New circle',exact:true})).toBeVisible();await page.getByLabel('Circle name',{exact:true}).fill('Reading circle');
 await page.getByRole('button',{name:'Create circle',exact:true}).click();await expect.poll(()=>created?.name).toBe('Reading circle');
 await expect(page.getByRole('dialog',{name:'New circle',exact:true})).toHaveCount(0);
});

test('closing provider sign-in cancels the wait without saving contacts',async({page,context})=>{
 await context.route('**/oauth-fixture',route=>route.fulfill({contentType:'text/html',body:'<p>Synthetic sign-in page.</p>'}));
 await page.route('**/api/address-book/oauth/start',route=>route.fulfill({json:{provider:'google',resultKey:'pending',authorizationUrl:'https://contact-provider.example.test/oauth-fixture'}}));
 await page.route('**/api/address-book/oauth/results/pending',route=>route.fulfill({status:404,json:{message:'Pending'}}));
 await page.goto('/contacts');await page.locator('summary').filter({hasText:'Import contacts'}).click();
 const popupPromise=page.waitForEvent('popup');await page.getByRole('button',{name:'Sign in with Google',exact:true}).click();
 const popup=await popupPromise;await popup.close();
 await expect(page.locator('main').getByText('Sign-in cancelled. No contacts were saved.',{exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'Sign in with Google',exact:true})).toBeEnabled();
 await expect(page.getByRole('heading',{name:'0 saved contacts',exact:true})).toBeVisible();
});

test('blocked provider popup does not start an OAuth attempt',async({page})=>{
 let starts=0;page.on('request',request=>{if(request.url().includes('/oauth/start'))starts++;});
 await page.goto('/contacts');await page.locator('summary').filter({hasText:'Import contacts'}).click();
 await page.evaluate(()=>{window.open=()=>null;});await page.getByRole('button',{name:'Sign in with Microsoft',exact:true}).click();
 await expect(page.locator('main').getByRole('alert')).toContainText('Allow pop-ups');expect(starts).toBe(0);
});
