import {test,expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('circle tree expands people and paginated private contacts without opening chat',async({page})=>{
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:900})));
 const circle={id:7,name:'Hyderabad Cycle Club',description:'Weekend rides',ownerName:'You',ownedByCurrentUser:true,members:[{person:{id:1,displayName:'Circle owner'},admin:true,creator:true},{person:{id:2,displayName:'Rider Alex'},admin:false,creator:false}]};
 const contact=(id:number,name:string)=>({id,displayName:name,phones:[],emails:[`rider${id}@example.test`],groups:[],circleIds:[7]});
 const requests:string[]=[];
 await page.route('**/api/**',async route=>{
  const url=new URL(route.request().url()),path=url.pathname;
  requests.push(path);
  const data=path==='/api/auth/me'?{id:1,username:'Owner',role:'USER'}:path==='/api/network/circles'?[circle]:path==='/api/address-book/circles'?[{id:7,name:circle.name,privateContactCount:2}]:path==='/api/address-book'?(url.searchParams.get('afterId')==='11'?{items:[contact(12,'Private rider two')],total:2,nextCursor:null}:{items:[contact(11,'Private rider one')],total:2,nextCursor:11}):path.includes('unread')?{count:0}:{};
  await route.fulfill({json:data});
 });
 await page.goto('/circles');
 const branch=page.getByRole('button',{name:'Open Hyderabad Cycle Club',exact:true});
 await expect(branch).toHaveAttribute('aria-expanded','false');
 await expect(page.getByRole('textbox',{name:'Type a message'})).toHaveCount(0);
 await branch.click();await expect(branch).toHaveAttribute('aria-expanded','true');
 await expect(page.getByRole('link',{name:'Rider Alex'})).toBeVisible();
 await expect(page.locator('main').getByRole('link',{name:'Messages',exact:true})).toHaveAttribute('href','/messages?circle=7');
 expect(requests.some(path=>path.includes('/posts'))).toBe(false);
 await page.getByRole('button',{name:'Show private contacts (2)',exact:true}).click();
 await expect(page.getByText('Private rider one',{exact:false})).toBeVisible();
 await page.getByRole('button',{name:'Load more contacts',exact:true}).click();
 await expect(page.getByText('Private rider two',{exact:false})).toBeVisible();
 await expect(page.getByRole('button',{name:'All contacts shown'})).toBeDisabled();
 await page.screenshot({path:test.info().outputPath('circle-tree.png'),fullPage:true});
 expect((await new AxeBuilder({page}).include('main').withTags(['wcag2a','wcag2aa']).analyze()).violations).toEqual([]);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 await page.getByRole('button',{name:'Collapse all'}).click();await expect(page.getByText('Private rider one',{exact:false})).toHaveCount(0);
 await page.getByRole('searchbox',{name:'Search circles'}).fill('Rider Alex');await expect(branch).toBeVisible();
});
