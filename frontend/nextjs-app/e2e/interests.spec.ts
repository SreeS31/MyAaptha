import {test,expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
test.beforeEach(async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:900})));
});
test('interests picker saves multiple choices and custom interests; area groups support creation and admin approval',async({page},info)=>{
 let interests=['Carrom'];let groups:any[]=[];let requests=[{userId:2,name:'Cycle member'}];let messages:any[]=[];
 await page.route('**/api/**',async route=>{
  const request=route.request(),url=new URL(request.url()),path=url.pathname,method=request.method();let body:any=[];
  if(path==='/api/auth/me')body={id:1,username:'club-admin',role:'USER'};
  else if(path==='/api/settings/me')body={};
  else if(path==='/api/interests/me'){if(method==='PUT')interests=request.postDataJSON().interests;body=interests;}
  else if(path==='/api/interests/groups'){
   if(method==='POST'){const input=request.postDataJSON();groups=[{id:'club-1',...input,admin:true,membership:'ACTIVE',memberCount:1}];body=groups[0];}
   else {const area=url.searchParams.get('area')||'';body={items:groups.filter(g=>g.area.toLowerCase().includes(area.toLowerCase())),hasNext:false};}
  }
  else if(path.endsWith('/requests/2')){expect(request.postDataJSON().approve).toBe(true);requests=[];body=null;}
  else if(path.endsWith('/requests'))body={items:requests,hasNext:false};
  else if(path.endsWith('/messages')){if(method==='POST'){messages=[{id:'msg-1',author:'club-admin',body:request.postDataJSON().body,createdAt:'2026-11-17T08:00:00Z',mine:true}];body=null;}else body={items:messages,hasNext:false};}
  else if(path.includes('/messages/msg-1')){messages=[];body=null;}
  else if(path.includes('unread'))body={count:0};
  await route.fulfill({json:body});
 });
 await page.goto('/interests');await page.getByRole('button',{name:'Edit interests',exact:true}).click();
 await page.getByLabel('Add from available interests').selectOption('Cycling');
 await page.getByLabel('Find a hobby or interest').fill('Bird sketching');await page.getByRole('button',{name:'Add “Bird sketching”'}).click();
 await page.getByRole('button',{name:'Save interests',exact:true}).click();await expect(page.getByRole('status')).toContainText('Your interests have been saved.');
 expect(interests).toEqual(['Carrom','Cycling','Bird sketching']);await page.reload();await expect(page.getByRole('button',{name:'Bird sketching',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Create a group',exact:true}).click();
 await page.getByLabel('Group name',{exact:true}).fill('Hyderabad Cycle Club');await page.getByLabel('Group interest',{exact:true}).fill('Cycling');await page.getByLabel('Group area',{exact:true}).fill('Hyderabad, India');await page.getByLabel('About this group').fill('Weekend cycling and friendly route discussions.');await page.getByRole('button',{name:'Create group',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Hyderabad Cycle Club',exact:true}).last()).toBeVisible();
 await page.getByRole('button',{name:'Approve Cycle member',exact:true}).click();await expect(page.getByText('No pending requests.')).toBeVisible();
 await page.getByLabel('Message to the group').fill('Sunday ride at 7 am?');await page.getByRole('button',{name:'Post message',exact:true}).click();await expect(page.getByText('Sunday ride at 7 am?',{exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Delete message',exact:true}).click();await expect(page.getByText('Sunday ride at 7 am?',{exact:true})).toHaveCount(0);
 await page.getByLabel('Area',{exact:true}).fill('Mumbai');await expect(page.getByRole('heading',{name:'No groups found'})).toBeVisible();await page.getByLabel('Area',{exact:true}).fill('Hyderabad');await expect(page.locator('.interest-group')).toHaveCount(1);
 const axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();expect(axe.violations).toEqual([]);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);await page.screenshot({path:info.outputPath('interests-groups.png'),fullPage:true});
});
test('joining requires admin approval and pending users cannot load group messages',async({page})=>{
 let membership:string|null=null;let reads=0;
 await page.route('**/api/**',async route=>{const path=new URL(route.request().url()).pathname;let body:any=[];
  const group={id:'club-2',name:'All India Shooter Club',topic:'Sport shooting',area:'India',description:'Sport and safety discussions.',admin:false,membership,memberCount:4};
  if(path==='/api/auth/me')body={id:3,username:'requester',role:'USER'};
  else if(path==='/api/settings/me')body={};
  else if(path==='/api/interests/groups')body={items:[group],hasNext:false};
  else if(path==='/api/interests/groups/club-2')body=group;
  else if(path.endsWith('/join')){membership='REQUESTED';body={...group,membership};}
  else if(path.endsWith('/membership')){membership=null;body={...group,membership};}
  else if(path.endsWith('/messages')){reads++;body={items:[],hasNext:false};}
  else if(path.includes('unread'))body={count:0};
  await route.fulfill({json:body});
 });
 await page.goto('/interests');await page.getByRole('button',{name:'View group',exact:true}).click();await page.getByRole('button',{name:'Request to join',exact:true}).click();
 await expect(page.getByText('Your request is awaiting admin approval.',{exact:false})).toBeVisible();expect(reads).toBe(0);
 await expect(page.getByRole('button',{name:'Post message',exact:true})).toHaveCount(0);await page.getByRole('button',{name:'Cancel join request',exact:true}).click();expect(membership).toBe(null);
 await page.getByRole('button',{name:'View group',exact:true}).click();await page.getByRole('button',{name:'Request to join',exact:true}).click();membership='ACTIVE';await page.getByRole('button',{name:'Refresh group',exact:true}).click();await expect(page.getByRole('button',{name:'Post message',exact:true})).toBeVisible();expect(reads).toBe(1);
});

