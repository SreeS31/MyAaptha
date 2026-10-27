import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';

test('information controls share heading space and retain full guidance',async({page,playwright},info)=>{
  test.setTimeout(240000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const username=`inline-${randomUUID().slice(0,8)}`,password=`Inline-${randomUUID()}`;
  try{
    expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1886${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).ok()).toBe(true);
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    for(const path of ['/relationship-tree','/contacts','/discover','/privacy','/ai-activity','/settings']){
      await page.goto(path);
      if(path==='/relationship-tree'){
        const broadcast=page.getByRole('button',{name:'Message your tree',exact:false});
        const guidance=page.getByRole('button',{name:'Tree message audience',exact:true});
        const toggleRect=await broadcast.boundingBox(),helpRect=await guidance.boundingBox();
        expect(Math.abs((toggleRect!.y+toggleRect!.height/2)-(helpRect!.y+helpRect!.height/2))).toBeLessThan(6);
        await guidance.click();await expect(page.locator('.broadcast-heading .info-panel')).toContainText('Same level');
        await page.keyboard.press('Escape');
        await broadcast.click();await expect(broadcast).toHaveAttribute('aria-expanded','true');
        await broadcast.click();await expect(broadcast).toHaveAttribute('aria-expanded','false');
      }
      const group=page.locator('.inline-help-heading,.page-heading-title').filter({has:page.locator('.info-trigger')}).first();
      await expect(group).toBeVisible();
      const heading=await group.locator('h1,h2,h3').first().boundingBox();
      const button=group.locator('.info-trigger').first(),rect=await button.boundingBox();
      // Inline text and button line boxes can differ slightly at their baselines.
      expect(Math.abs((rect!.y+rect!.height/2)-(heading!.y+heading!.height/2)),path).toBeLessThan(10);
      expect(rect!.x-heading!.x-heading!.width,path).toBeLessThan(18);
      await button.click();await expect(button).toHaveAttribute('aria-expanded','true');
      await expect(group.locator('.info-panel')).toBeVisible();
      const panel=await group.locator('.info-panel').boundingBox();expect(panel!.x).toBeGreaterThanOrEqual(0);expect(panel!.x+panel!.width).toBeLessThanOrEqual(page.viewportSize()!.width+1);
      if(path==='/relationship-tree')await page.screenshot({path:`../../.tools/preview/inline-help-${info.project.name}.png`});
      await button.focus();await page.keyboard.press('Tab');await expect(group.locator('.info-panel')).toBeFocused();
      await page.keyboard.press('Escape');await expect(button).toHaveAttribute('aria-expanded','false');await expect(button).toBeFocused();
      expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),path).toBe(true);
    }
  }finally{await api.dispose();}
});
