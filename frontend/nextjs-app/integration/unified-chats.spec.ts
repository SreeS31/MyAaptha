import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';
test.use({actionTimeout:15000});

test('mixed forwarding is limited to ten and circle chats open from Messages',async({page,playwright})=>{
  test.setTimeout(180000);
  const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
  const password=`Chat-${randomUUID()}`;
  async function member(){
    const username=`unified-${randomUUID().slice(0,8)}`;
    const created=await api.post('/api/users',{data:{username,password,phoneNumber:`+1877${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}});expect(created.status()).toBe(200);
    const auth=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(auth.status()).toBe(200);
    return {...await created.json(),username,headers:{Authorization:`Bearer ${(await auth.json()).accessToken}`}};
  }
  try{
    const user=await member(),friend=await member();
    expect((await api.post('/api/network/relationships',{headers:user.headers,data:{relatedUserId:friend.id,type:'Friend',visibilityScope:'FRIENDS'}})).status()).toBe(200);
    const sent=await api.post(`/api/network/messages/with/${friend.id}`,{headers:user.headers,multipart:{message:'Mixed forward example'}});expect(sent.status()).toBe(200);const message=await sent.json();
    const groups:{id:number;name:string}[]=[];
    for(let index=0;index<10;index++){
      const name=`Circle ${String(index+1).padStart(2,'0')}`;
      const created=await api.post('/api/network/circles',{headers:user.headers,data:{name,description:'Forwarding test'}});expect(created.status()).toBe(200);groups.push({id:(await created.json()).id,name});
    }
    await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(user.username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
    await page.goto(`/dashboard?messageUserId=${friend.id}`);
    await page.getByRole('button',{name:`Actions for message ${message.id}`,exact:true}).click();
    await page.getByRole('menuitem',{name:'Forward',exact:true}).click();
    const picker=page.getByRole('dialog',{name:'Forward message',exact:true});
    await expect(picker).toBeVisible();await picker.getByRole('checkbox',{name:new RegExp(`^${friend.username} Person$`,'i')}).check();
    for(const group of groups.slice(0,9))await picker.getByRole('checkbox',{name:`${group.name} Circle`,exact:true}).check();
    await expect(picker.getByRole('status')).toHaveText('10 / 10 selected');
    await expect(picker.getByRole('checkbox',{name:'Circle 10 Circle',exact:true})).toBeDisabled();
    await picker.getByRole('searchbox').fill('Circle 01');await expect(picker.getByRole('checkbox')).toHaveCount(1);
    await picker.getByRole('searchbox').fill('');
    await page.screenshot({path:`../../.tools/preview/unified-forward-${test.info().project.name}.png`});
    const forwarded=page.waitForResponse(response=>response.url().endsWith('/api/network/chats/forward')&&response.request().method()==='POST');
    await picker.getByRole('button',{name:'Send forward',exact:true}).click();
    expect((await forwarded).status()).toBe(200);
    await expect(picker).toHaveCount(0);
    await page.goto('/messages');
    await expect(page.getByRole('heading',{name:'Messages',exact:true})).toBeVisible();
    await expect(page.locator('.chat-inbox-row')).toHaveCount(11);
    await page.getByRole('button',{name:'Groups & circles',exact:true}).click();await expect(page.locator('.chat-inbox-row')).toHaveCount(10);
    const circle=page.locator('.chat-inbox-row').filter({hasText:'Circle 01'});
    await expect(circle).toContainText('Mixed forward example');
    await circle.getByRole('button').click();
    await expect(page.locator('.chat-thread')).toBeVisible();
    await expect(page.locator('.chat-thread')).toContainText('Mixed forward example');
    const bubble=page.locator('.chat-thread .chat-bubble').first();
    const sender=await bubble.locator('.chat-sender').boundingBox(),body=await bubble.locator('.chat-message-text').boundingBox(),time=await bubble.locator('.chat-message-meta').boundingBox();
    expect(sender!.y).toBeLessThan(body!.y);expect(time!.y).toBeGreaterThan(body!.y);
    await expect(page.getByRole('textbox',{name:'Message text',exact:true})).toBeInViewport({ratio:1});
    await bubble.getByRole('button',{name:/Actions for message/}).click();
    await page.getByRole('menuitem',{name:'Info',exact:true}).click();
    await expect(page.getByRole('complementary',{name:'Message info',exact:true})).toBeVisible();
    await page.getByRole('button',{name:'Close message info',exact:true}).click();
    await bubble.getByRole('button',{name:/Actions for message/}).click();
    await page.getByRole('menuitem',{name:'Star',exact:true}).click();
    await expect(page.getByRole('menu',{name:'Message actions',exact:true})).toHaveCount(0);
    await page.locator('.chat-thread').getByRole('button',{name:/Actions for message/}).first().click();
    await expect(page.getByRole('menuitem',{name:'Unstar',exact:true})).toBeVisible();await page.keyboard.press('Escape');
    await page.locator('.chat-thread').getByRole('button',{name:/Actions for message/}).first().click();
    await page.screenshot({path:`../../.tools/preview/unified-menu-${test.info().project.name}.png`});
    await page.keyboard.press('Escape');
    await expect(page.getByRole('menu',{name:'Message actions',exact:true})).toHaveCount(0);
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
  }finally{await api.dispose();}
});
