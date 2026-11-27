import {test,expect} from '@playwright/test';
for(const member of [101,null])test(`tree Message ${member?'opens the matched direct chat':'explains unavailable contacts'}`,async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 const nodes=Array.from({length:3},(_,i)=>({key:'n'+i,name:'Person '+i,relation:'Connection',contactId:i===0?42:null,parentKey:null,gender:'UNSPECIFIED'}));
 await page.route('**/api/**',async route=>{const path=new URL(route.request().url()).pathname;let data:unknown=[];
 if(path==='/api/auth/me')data={id:1,username:'Owner',role:'USER'};
 else if(path==='/api/profile/me')data={photos:[]};
 else if(path==='/api/settings/me')data={};
 else if(path.includes('unread'))data={count:0};
 else if(path==='/api/relationship-trees')data={items:[{id:1,name:'Office',count:3,version:1,preview:nodes}],nextCursor:null};
 else if(path==='/api/relationship-trees/1')data={id:1,name:'Office',version:1,nodes};
 else if(path.endsWith('/person'))data={...nodes[0],phones:['+19990000001'],emails:[],organization:'',groups:[],contactAvailable:true};
 else if(path.endsWith('/message-target'))data={userId:member,name:member?'Member':null};
 await route.fulfill({json:data});});
 await page.goto('/relationship-tree?view=saved');await page.getByRole('button',{name:'Office (3 people)',exact:true}).click();await page.getByRole('button',{name:'Person: Person 0',exact:true}).click();
 const details=page.getByRole('complementary',{name:'Person information'}),button=details.getByRole('button',{name:'Message',exact:true});await expect(button).toBeEnabled();await button.click();
 if(member)await expect(page).toHaveURL(/\/messages\?person=101$/);else{await expect(details.getByText('This person is not available for MyAaptha messaging.',{exact:true})).toBeVisible();await expect(page).toHaveURL(/relationship-tree/);await expect(button).toBeEnabled();}
});
