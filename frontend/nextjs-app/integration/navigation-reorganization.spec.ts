import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';
import {menuMoves,primaryNavigation} from '../app/lib/workspace-navigation';

test('new menu preserves destinations, section tabs and shared career/interests data',async({page,playwright},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`nav-${randomUUID().slice(0,10)}`,password=`Nav-${randomUUID()}`;
 const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1885${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  const auth=await(await api.post('/api/auth/login',{data:{identifier:username,password}})).json();
  const headers={Authorization:`Bearer ${auth.accessToken}`};
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
  await page.goto('/menu-comparison');await expect(page.getByRole('heading',{name:'Old menu to new home'})).toBeVisible();
  const comparison=page.getByRole('region',{name:'Menu comparison'});
  await expect(comparison.locator('article')).toHaveCount(menuMoves.length);
  for(const move of menuMoves)await expect(comparison.locator(`a[href="${move.href}"]`)).toHaveCount(1);
  // The collapsed phone drawer must contain the same nine categories, with no old duplicates.
  if(info.project.name==='mobile-web')await page.getByRole('button',{name:'Toggle main menu'}).click();
  const sidebar=page.getByRole('complementary',{name:'Main navigation'});
  for(const item of primaryNavigation)await expect(sidebar.locator(`a[href="${item.href}"]`)).toBeVisible();
  await expect(sidebar.getByRole('link',{name:'Life timeline',exact:true})).toHaveCount(0);
  await expect(sidebar.getByRole('link',{name:'My circles',exact:true})).toHaveCount(0);
  if(info.project.name==='mobile-web')await page.keyboard.press('Escape');
  await page.goto('/timeline');const dashboardTabs=page.getByRole('navigation',{name:'Dashboard sections'});
  await expect(dashboardTabs.getByRole('link',{name:'Life timeline',exact:true})).toHaveAttribute('aria-current','page');
  await dashboardTabs.getByRole('link',{name:'Trust center',exact:true}).click();await expect(page).toHaveURL(/trust/);
  await page.goto('/messages');const messageTabs=page.getByRole('navigation',{name:'Messages sections'});
  await messageTabs.getByRole('link',{name:'My contacts',exact:true}).click();await expect(page).toHaveURL(/contacts/);
  await expect(page.getByRole('navigation',{name:'Messages sections'}).getByRole('link',{name:'My contacts'})).toHaveAttribute('aria-current','page');
  await page.getByRole('navigation',{name:'Messages sections'}).getByRole('link',{name:'My circles'}).click();await expect(page).toHaveURL(/circles/);
  await page.goto('/career');const employment=page.getByRole('region',{name:'Employment',exact:true});
  await employment.getByRole('button',{name:'Edit Employment',exact:true}).click();await employment.getByLabel('Employer / Organizations (separate multiple with commas)',{exact:true}).fill('Navigation test employer');await employment.getByRole('button',{name:'Save Employment',exact:true}).click();
  await expect(employment.getByText('Navigation test employer',{exact:true})).toBeVisible();
  await page.goto('/interests');const interests=page.getByRole('region',{name:'Interests',exact:true});await interests.getByRole('button',{name:'Edit Interests',exact:true}).click();await interests.getByLabel('Hobbies & interests (separate with commas)',{exact:true}).fill('Reading, Gardening');await interests.getByRole('button',{name:'Save Interests',exact:true}).click();await expect(interests.getByText('Reading, Gardening',{exact:true})).toBeVisible();
  let profile=await(await api.get('/api/profile/me',{headers})).json();expect(profile.hobbies).toBe('Reading, Gardening');expect(profile.employer).toBe('Navigation test employer');
  await page.goto('/profile');await expect(page.getByRole('region',{name:'Interests',exact:true})).toContainText('Reading, Gardening');
  await page.goto('/online-feed');await expect(page.getByRole('heading',{name:'Online Feed',exact:true})).toBeVisible();
  const audience=page.getByRole('combobox',{name:'Who can view this?',exact:true});await expect(audience).toHaveValue('PRIVATE');await audience.selectOption('FRIENDS');await audience.selectOption('CIRCLE');await expect(page.getByRole('combobox',{name:'Select a circle',exact:true})).toBeVisible();
  await page.getByRole('navigation',{name:'Online Feed sections'}).getByRole('link',{name:'Following & followers'}).click();await expect(page).toHaveURL(/following/);
  await page.goto('/workspace-tools');for(const path of ['/settings','/session','/ai-activity','/help','/reports','/moderation'])await expect(page.locator(`main a[href="${path}"]`)).toBeVisible();
  await page.goto('/menu-comparison');await page.screenshot({path:`../../.tools/preview/navigation-${info.project.name}.png`,fullPage:true});
  await page.screenshot({path:`../../.tools/preview/navigation-${info.project.name}-viewport.png`});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)).toBe(false);expect(errors).toEqual([]);
 }finally{await api.dispose();}
});
