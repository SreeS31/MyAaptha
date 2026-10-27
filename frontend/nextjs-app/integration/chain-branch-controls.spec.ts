import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('branch plus receives pointer clicks independently of the person details button',async({page,playwright},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`branch-${randomUUID().slice(0,9)}`,password=`Branch-${randomUUID()}`;
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1883${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);
  const relation=(id:number,name:string,anchor:number|null)=>({id,type:'Brother',relativeToUserId:anchor,visibilityScope:'FRIENDS',person:{id,displayName:name,gender:'Male',accountStatus:'ACTIVE',identityType:'ACCOUNT'}});
  await page.route('**/api/network/relationships',route=>route.fulfill({json:[relation(910001,'Branch parent',null),relation(910002,'Branch child',910001),relation(910003,'Branch grandchild',910002)]}));
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/relationship-tree');await page.getByRole('button',{name:'Chain explorer',exact:true}).click();
  const explorer=page.getByRole('region',{name:'Relationship chain explorer'});
  await explorer.getByRole('button',{name:'Reset branches',exact:true}).click();
  const parent=explorer.getByRole('button',{name:'Expand branch for Branch parent',exact:true});await expect(parent).toBeVisible();
  await expect(explorer.getByRole('button',{name:'View details for Branch child',exact:true})).toHaveCount(0);
  // Use a real pointer at the visible plus centre, not a forced DOM click.
  const identity=explorer.getByRole('button',{name:'View details for Branch parent',exact:true});
  await identity.click();await expect(explorer.getByRole('complementary',{name:'Branch parent details'})).toBeVisible();
  if(info.project.name==='desktop')await identity.hover();
  await parent.scrollIntoViewIfNeeded();
  const box=await parent.boundingBox();expect(box).not.toBeNull();
  if(info.project.name==='mobile-web')await page.touchscreen.tap(box!.x+box!.width/2,box!.y+box!.height/2);else await page.mouse.click(box!.x+box!.width/2,box!.y+box!.height/2);
  await expect(explorer.getByRole('button',{name:'Collapse branch for Branch parent',exact:true})).toHaveAttribute('aria-expanded','true');
  await expect(explorer.getByRole('button',{name:'View details for Branch child',exact:true})).toBeVisible();
  await expect(explorer.getByRole('complementary',{name:'Branch parent details'})).toBeVisible();
  await explorer.getByRole('button',{name:'Close person details',exact:true}).click();
  await explorer.getByRole('button',{name:'Expand branch for Branch child',exact:true}).click();await expect(explorer.getByRole('button',{name:'View details for Branch grandchild',exact:true})).toBeVisible();
  await explorer.getByRole('button',{name:'View details for Branch parent',exact:true}).click();await expect(explorer.getByRole('complementary',{name:'Branch parent details'})).toBeVisible();
  await explorer.getByRole('button',{name:'Collapse chain',exact:true}).click();await expect(explorer.getByRole('button',{name:'View details for Branch child',exact:true})).toHaveCount(0);
  await explorer.getByRole('button',{name:'Expand chain',exact:true}).click();await expect(explorer.getByRole('button',{name:'View details for Branch child',exact:true})).toBeVisible();
  await explorer.getByRole('button',{name:'Close person details',exact:true}).click();
  const collapse=explorer.getByRole('button',{name:'Collapse branch for Branch parent',exact:true});await collapse.focus();await page.keyboard.press('Space');await expect(explorer.getByRole('button',{name:'View details for Branch child',exact:true})).toHaveCount(0);
  await explorer.getByRole('button',{name:'Expand all',exact:true}).click();await expect(explorer.getByRole('button',{name:'View details for Branch grandchild',exact:true})).toBeVisible();
  await page.screenshot({path:`../../.tools/preview/branch-controls-${info.project.name}.png`});expect(errors).toEqual([]);
 }finally{await api.dispose();}
});
