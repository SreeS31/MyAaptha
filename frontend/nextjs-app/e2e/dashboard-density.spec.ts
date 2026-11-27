import {test,expect} from '@playwright/test';

for(const populated of [false,true])test(`dashboard keeps ${populated?'populated':'empty'} data without repeated navigation or explanations`,async({page},info)=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;
  const data=path==='/api/auth/me'?{id:1,username:'Member',role:'USER'}
   :path==='/api/profile/me'?{firstName:'Member',photos:[]}
   :path==='/api/network/relationships'&&populated?[{id:1,type:'Friend',person:{id:2,displayName:'Alex',accountStatus:'ACTIVE'}},{id:2,type:'Friend',person:{id:3,displayName:'Robin',accountStatus:'ACTIVE'}}]
   :path==='/api/network/circles'&&populated?[{id:1,name:'Cycling',members:[{person:{id:2,displayName:'Alex',accountStatus:'ACTIVE'},admin:false}],ownerUserId:1,ownerName:'Member',ownedByCurrentUser:true,currentUserAdmin:true,currentUserCanPost:true,postingPermission:'ALL_MEMBERS'}]
   :path==='/api/address-book/providers'?{google:false,microsoft:false}
   :path.includes('unread')?{count:0}:[];
  await route.fulfill({json:data});
 });
 await page.goto('/dashboard');
 await expect(page.getByRole('heading',{name:'Dashboard',exact:true})).toBeVisible();
 await expect(page.locator('.user-dashboard-metrics article')).toHaveCount(5);
 const destinations=['/relationship-tree','/circles','/managed-profiles','/messages?filter=unread','/notifications'];
 for(let index=0;index<destinations.length;index++)await expect(page.locator('.user-dashboard-metrics article').nth(index).getByRole('link')).toHaveAttribute('href',destinations[index]);
 await expect(page.getByRole('navigation',{name:'Dashboard shortcuts'})).toHaveCount(0);
 await expect(page.getByLabel('Quick actions',{exact:true})).toHaveCount(0);
 const network=page.getByRole('region',{name:'Network summary',exact:true});
 await expect(network.getByRole('heading')).toHaveCount(1);
 await expect(network.getByRole('heading')).toHaveText('Network');
 if(populated){await expect(network.locator('.insight-bars li')).toHaveCount(1);await expect(network.locator('.insight-bars strong')).toHaveText('2');}
 else await expect(network.getByText('No relationships',{exact:true})).toBeVisible();
 await network.getByRole('button',{name:'Circles',exact:true}).click();
 if(populated){await expect(network.getByText('Cycling',{exact:true})).toBeVisible();await expect(network.locator('.insight-bars strong')).toHaveText('1');}
 else await expect(network.getByText('No circles',{exact:true})).toBeVisible();
 await expect(page.locator('.timeline-dashboard-preview').getByText('No events',{exact:true})).toBeVisible();
 await expect(page.getByText('Your network at a glance',{exact:true})).toHaveCount(0);
 await expect(page.getByText('Counts from your saved relationships.',{exact:true})).toHaveCount(0);
 await expect(page.locator('.contact-organizer').getByRole('button',{name:'Import contacts',exact:true})).toHaveText('Import contacts');
 await page.screenshot({path:info.outputPath(`dashboard-${populated?'populated':'empty'}.png`),fullPage:true});
 await page.locator('.user-dashboard-metrics article').nth(2).getByRole('link').click();
 await expect(page).toHaveURL(/\/managed-profiles$/);
});
