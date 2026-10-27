import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';
test.use({actionTimeout:15000});
test('tree preview and delivery honor the selected relationship depth',async({page,playwright})=>{
  test.setTimeout(240000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const password=`Tree-${randomUUID()}`;
  async function member(){const username=`levels-${randomUUID().slice(0,8)}`,phoneNumber=`+1876${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`;const result=await api.post('/api/users',{data:{username,password,phoneNumber}});expect(result.ok()).toBe(true);const user=await result.json();let auth=await api.post('/api/auth/login',{data:{identifier:username,password}});if(auth.status()===429){await page.waitForTimeout(60000);auth=await api.post('/api/auth/login',{data:{identifier:username,password}});}expect(auth.ok(),`Test login status ${auth.status()}`).toBe(true);return {...user,username,phoneNumber,headers:{Authorization:`Bearer ${(await auth.json()).accessToken}`}};}
  try{
    const owner=await member(),parent=await member(),child=await member(),grandchild=await member();
    for(const [person,anchor] of [[parent,null],[child,parent.id],[grandchild,child.id]] as const){const result=await api.post('/api/network/relationships/add-person',{headers:owner.headers,data:{fullName:person.username,phoneNumber:person.phoneNumber,type:'Son',identityType:'ACCOUNT',visibilityScope:'RELATIVES',relativeToUserId:anchor}});expect(result.ok(),await result.text()).toBe(true);}
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(owner.username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await expect(page.getByRole('heading',{name:'Dashboard',exact:true})).toBeVisible();
    await expect(page.locator('.relationship-tree-section')).toHaveCount(0);
    expect(await page.locator('.workspace-nav-section').first().locator('a').evaluateAll(items=>items.slice(0,2).map(item=>item.getAttribute('href')))).toEqual(['/dashboard','/relationship-tree']);
    await page.route('**/api/network/relationships',async route=>{const response=await route.fetch();const rows=await response.json();await route.fulfill({response,json:rows.map((row:any)=>({...row,person:{...row.person,gender:row.person.id===child.id?'Female':'Male'}}))});});
    await page.goto('/relationship-tree');
    await expect(page.getByRole('heading',{name:'Relationship tree',exact:true})).toBeVisible();
    await expect(page.locator('.user-dashboard-metrics')).toHaveCount(0);
    await expect(page.getByText('My timeline',{exact:true})).toHaveCount(0);
    await expect(page.getByText('Import an address book',{exact:true})).toHaveCount(0);
    const addPanel=page.locator('#add-network-person'), broadcast=page.locator('#relationship-broadcast');
    await expect(addPanel).not.toHaveAttribute('open','');
    await expect(page.getByRole('button',{name:'Message your tree',exact:true})).toHaveAttribute('aria-expanded','false');
    const bounds=await page.locator('.tree-top-tools').evaluate(element=>Array.from(element.children).map(child=>{const r=child.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width};}));
    if(page.viewportSize()!.width>760){expect(Math.abs(bounds[0].y-bounds[1].y)).toBeLessThan(3);expect(bounds[1].x).toBeGreaterThan(bounds[0].x+bounds[0].width);}
    await addPanel.locator(':scope > summary').click();
    await expect(addPanel.getByPlaceholder('Full name',{exact:true})).toBeVisible();
    const help=addPanel.getByRole('button',{name:'Adding relationships',exact:true});await expect(help).toHaveAttribute('aria-expanded','false');await help.click();await expect(addPanel.locator('.info-panel')).toContainText('Contact details stay private');await page.keyboard.press('Escape');
    await expect(page.locator('.family-graph-node')).toHaveCount(4);
    await page.getByRole('button',{name:`Collapse branch for ${owner.username}`,exact:true}).click();
    await expect(page.locator('.family-graph-node')).toHaveCount(1);
    await page.getByRole('button',{name:`Expand branch for ${owner.username}`,exact:true}).click();
    await expect(page.locator('.family-graph-node')).toHaveCount(4);
    await page.getByRole('button',{name:'Chain explorer',exact:true}).click();
    const male=page.getByRole('button',{name:`Expand branch for ${parent.username}`,exact:true});
    await expect(male).toHaveCSS('background-color','rgb(56, 118, 214)');await male.click();
    const female=page.getByRole('button',{name:`Expand branch for ${child.username}`,exact:true});
    await expect(female).toHaveCSS('background-color','rgb(213, 62, 131)');await female.click();
    await expect(page.getByRole('img',{name:`${grandchild.username}: end of available chain`,exact:true})).toHaveCSS('background-color','rgb(255, 255, 255)');
    await page.getByRole('button',{name:'Message your tree',exact:true}).click();
    await page.screenshot({path:`../../.tools/preview/tree-tools-open-${test.info().project.name}.png`,fullPage:true});
    await page.getByRole('combobox',{name:'Starting person',exact:true}).selectOption(String(parent.id));
    await page.getByRole('combobox',{name:'Relationship levels',exact:true}).selectOption('2');
    await page.getByRole('button',{name:'Preview audience',exact:true}).click();
    await expect(page.locator('.broadcast-preview')).toContainText('1 recipients');
    const message=`Second level only ${randomUUID()}`;
    await page.locator('.broadcast-composer textarea').fill(message);
    await page.getByRole('button',{name:'Send privately',exact:true}).click();
    await expect(page.locator('.network-message')).toContainText('Broadcast delivered privately to 1 person');
    const read=async(id:number)=>{const response=await api.get(`/api/network/messages/with/${id}`,{headers:owner.headers});expect(response.ok()).toBe(true);return JSON.stringify(await response.json());};
    expect(await read(grandchild.id)).toContain(message);expect(await read(child.id)).not.toContain(message);expect(await read(parent.id)).not.toContain(message);
    await page.locator('.broadcast-modes input').nth(1).check();
    await page.getByRole('combobox',{name:'Relationship levels',exact:true}).selectOption('1');
    await page.getByRole('button',{name:'Preview audience',exact:true}).click();await expect(page.locator('.broadcast-preview')).toContainText('2 recipients');
    await page.screenshot({path:`../../.tools/preview/tree-levels-${test.info().project.name}.png`});
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  }finally{await api.dispose();}
});
