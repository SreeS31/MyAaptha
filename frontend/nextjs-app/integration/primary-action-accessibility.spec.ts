import {expect,test} from './fixtures';
import AxeBuilder from '@axe-core/playwright';
import {randomUUID} from 'node:crypto';

test('shared primary actions retain contrast on hover and keyboard focus',async({page,playwright})=>{
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`primary-a11y-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
  try{
    expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1873${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    for(const [path,name] of [['/circles','Create circle'],['/timeline','Add event'],['/health','Add a measurement']]){
      await page.goto(path);
      const button=page.getByRole('button',{name,exact:true});await expect(button).toBeEnabled({timeout:15000});
      await button.evaluate(element=>element.setAttribute('data-accessibility-target','primary'));
      await button.hover();
      const hover=await new AxeBuilder({page}).include('[data-accessibility-target="primary"]').withRules(['color-contrast','button-name']).analyze();
      expect(hover.violations,`${path}: hover`).toEqual([]);
      await page.locator('main h1').first().hover();await button.focus();
      await page.keyboard.press('Tab');await page.keyboard.press('Shift+Tab');await expect(button).toBeFocused();
      const focus=await new AxeBuilder({page}).include('[data-accessibility-target="primary"]').withRules(['color-contrast','button-name']).analyze();
      expect(focus.violations,`${path}: focus`).toEqual([]);
      expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),`${path}: viewport`).toBe(true);
    }
  }finally{await api.dispose();}
});
