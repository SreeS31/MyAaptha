import {test,expect} from '@playwright/test';
test('top finder searches this page without searching the navigation',async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 await page.route('**/api/**',async route=>{const path=new URL(route.request().url()).pathname;let data:unknown=[];if(path==='/api/auth/me')data={id:1,username:'Owner',role:'USER'};else if(path==='/api/profile/me')data={photos:[]};else if(path==='/api/settings/me')data={};else if(path.includes('unread'))data={count:0};else if(path==='/api/relationship-trees')data={items:[{id:1,name:'Office',count:3,version:1,preview:[]}],nextCursor:null};await route.fulfill({json:data});});
 await page.goto('/relationship-tree?view=saved');const search=page.getByRole('search',{name:'Find people & Circles'});await expect(search).toBeVisible();await search.getByRole('searchbox').fill('Office');await search.getByRole('button',{name:'Run people and circles search',exact:true}).click();await expect(search.getByRole('status')).toHaveText('1 of 1');await expect(page.getByRole('button',{name:'Office (3 people)',exact:true})).toHaveClass(/page-discover-match/);
 await search.getByRole('searchbox').fill('Sign out');await search.getByRole('button',{name:'Run people and circles search',exact:true}).click();await expect(search.getByRole('status')).toHaveText('No matches on this page');await search.getByRole('button',{name:'Clear search'}).click();await expect(search.getByRole('searchbox')).toHaveValue('');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});

test('merged finder returns people and circles without duplicate side navigation',async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 await page.route('**/api/**',async route=>{
  const path=new URL(route.request().url()).pathname;let data:unknown=[];
  if(path==='/api/auth/me')data={id:1,username:'Owner',role:'USER'};
  else if(path==='/api/profile/me')data={photos:[]};
  else if(path==='/api/settings/me')data={};
  else if(path.includes('unread'))data={count:0};
  else if(path==='/api/network/discover')data={people:[{person:{id:42,displayName:'Office Alex'}}]};
  else if(path==='/api/network/circles')data=[{id:7,name:'Office circle',description:'Office contacts',members:[],ownerUserId:1,ownerName:'Owner',ownedByCurrentUser:true,currentUserAdmin:true,currentUserCanPost:true,postingPermission:'ALL_MEMBERS'}];
  await route.fulfill({json:data});
 });
 await page.goto('/dashboard');
 const search=page.getByRole('search',{name:'Find people & Circles'});
 await search.getByRole('searchbox').fill('Office');
 await search.getByRole('button',{name:'Run people and circles search',exact:true}).click();
 await expect(search.getByRole('link',{name:'Office Alex'})).toHaveAttribute('href','/people/42');
 await expect(search.getByRole('link',{name:'Office circle'})).toHaveAttribute('href','/circles?circle=7');
 await expect(search.getByRole('link',{name:'All search results'})).toHaveAttribute('href','/circle-search?q=Office');
 await expect(page.locator('aside').getByRole('link',{name:/Find people|Discover/})).toHaveCount(0);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});
