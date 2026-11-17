import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';
import {menuMoves} from '../app/lib/workspace-navigation';

test('single menu preserves destinations and profile data across API and web editors',async({page,playwright},info)=>{
 const api=await playwright.request.newContext({baseURL:'http://localhost:8080'});
 const name='nav'+randomUUID().replaceAll('-','').slice(0,16),password='Synthetic-'+randomUUID();
 try{
  const created=await api.post('/api/users',{data:{username:name,email:`${name}@example.test`,phoneNumber:'+1999'+Date.now().toString().slice(-10),password}});expect(created.ok()).toBeTruthy();
  await page.goto('/auth');await page.getByLabel('Username or mobile number').fill(name);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
  await page.goto('/messages');await expect(page.locator('.workspace-section-tabs')).toHaveCount(0);
  if(info.project.name.includes('mobile'))await page.getByRole('button',{name:'Toggle main menu'}).click();
  const sidebar=page.locator('#workspace-navigation');
  for(const item of menuMoves.filter(item=>item.href!=='/security-reports'))await expect(sidebar.locator(`a[href="${item.href}"]`)).toHaveCount(1);
  await sidebar.locator('a[href="/contacts"]').click();await expect(page).toHaveURL(/contacts/);
  await page.goto('/career');const employment=page.getByRole('region',{name:'Employment',exact:true});await employment.getByRole('button',{name:'Edit Employment'}).click();await employment.getByLabel('Employer / Organizations (separate multiple with commas)').fill('Navigation test employer');await employment.getByRole('button',{name:'Save Employment'}).click();
  await page.goto('/interests');await page.getByRole('button',{name:'Add interests',exact:true}).click();await page.getByLabel('Add from available interests').selectOption('Reading');await page.getByLabel('Add from available interests').selectOption('Gardening');await page.getByRole('button',{name:'Save interests',exact:true}).click();await expect(page.getByRole('status')).toContainText('saved');
  await page.goto('/profile');await expect(page.getByRole('region',{name:'Interests',exact:true})).toContainText('Reading, Gardening');await expect(page.getByRole('region',{name:'Employment',exact:true})).toContainText('Navigation test employer');
 }finally{await api.dispose();}
});
