import {test,expect,BrowserContext,Page} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Requires removable synthetic-account live-write opt-in');
test.use({launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required']}});
test.use({permissions:['camera'],launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required']}});
test('personal community features persist and enforce audiences on the live beta',async({browser},info)=>{
 test.setTimeout(240_000);const contexts:BrowserContext[]=[],accounts:{id:number;username:string;page:Page}[]=[];let postId:number|undefined,storyId:number|undefined;
 const headers={'X-MyAaptha-Web':'1',Origin:String(info.project.use.baseURL)};
 try{
  for(let index=0;index<2;index++){
   const context=await browser.newContext({baseURL:info.project.use.baseURL,viewport:info.project.use.viewport,isMobile:info.project.use.isMobile,hasTouch:info.project.use.hasTouch,userAgent:info.project.use.userAgent,permissions:['camera']});contexts.push(context);
   const page=await context.newPage();page.setDefaultTimeout(25_000);const username='pf23'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('base64url');
   const registered=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1997'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});expect(registered.ok()).toBe(true);const user=await registered.json();
   const file=resolve(__dirname,'../../../.tools/personal-features-live-fixtures-20261123.json'),fixtures=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(file,JSON.stringify(fixtures,null,2));accounts.push({id:user.id,username,page});
   await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth/);
  }
  const [owner,member]=accounts;
  for(const [a,b] of [[owner,member],[member,owner]])expect((await a.page.request.post('/api/network/relationships',{headers,data:{relatedUserId:b.id,type:'Friend',visibilityScope:'FRIENDS'}})).ok()).toBe(true);
  const circleResponse=await owner.page.request.post('/api/network/chats/groups',{headers,data:{name:'Synthetic activities '+owner.username,memberIds:[member.id]}});expect(circleResponse.ok()).toBe(true);const circle=await circleResponse.json(),path='/api/network/circles/'+circle.id+'/activities';
  const pollResponse=await owner.page.request.post(path,{headers,data:{kind:'POLL',title:'Weekend ride',options:['Morning','Evening'],multiple:false}});expect(pollResponse.ok()).toBe(true);const poll=await pollResponse.json();
  expect((await member.page.request.post(path+'/'+poll.id+'/vote',{headers,data:{optionIds:[poll.options[0].id]}})).ok()).toBe(true);
  const eventResponse=await owner.page.request.post(path,{headers,data:{kind:'EVENT',title:'Club meetup',startsAt:new Date(Date.now()+86400000).toISOString(),location:'Synthetic clubhouse'}});expect(eventResponse.ok()).toBe(true);const event=await eventResponse.json();expect((await member.page.request.post(path+'/'+event.id+'/rsvp',{headers,data:{response:'YES'}})).ok()).toBe(true);
  await owner.page.goto('/messages?circle='+circle.id);await owner.page.getByLabel('Circle options',{exact:true}).click();await owner.page.getByRole('button',{name:'Polls & events',exact:true}).click();const activities=owner.page.getByRole('dialog',{name:'Circle polls and events'});await expect(activities.getByText('1 votes',{exact:true})).toBeVisible();await expect(activities.getByRole('button',{name:'Going (1)',exact:true})).toBeVisible();await owner.page.screenshot({path:info.outputPath('live-polls-events.png'),fullPage:true});await activities.getByRole('button',{name:'Close',exact:true}).click();
  expect((await owner.page.request.post('/api/social/tools/close-friends/'+member.id,{headers})).ok()).toBe(true);
  const storyResponse=await owner.page.request.post('/api/social/stories',{headers,multipart:{caption:'Synthetic close friends story',audience:'CLOSE_FRIENDS',archive:'true'}});expect(storyResponse.ok()).toBe(true);const story=await storyResponse.json();storyId=story.id;
  expect((await member.page.request.post('/api/social/stories/'+story.id+'/view',{headers})).ok()).toBe(true);expect((await member.page.request.post('/api/social/tools/stories/'+story.id+'/reaction',{headers,data:{emoji:'\uD83D\uDC4D'}})).ok()).toBe(true);expect((await member.page.request.post('/api/social/tools/stories/'+story.id+'/reply',{headers,data:{message:'Synthetic story reply'}})).ok()).toBe(true);
  expect((await owner.page.request.post('/api/social/tools/stories/'+story.id+'/highlight',{headers,data:{name:'Synthetic highlights'}})).ok()).toBe(true);
  expect((await (await owner.page.request.get('/api/social/tools/stories/'+story.id+'/viewers')).json()).some((v:{id:number})=>v.id===member.id)).toBe(true);
  await owner.page.goto('/online-feed');await owner.page.getByRole('button',{name:'Highlights',exact:true}).click();await expect(owner.page.getByRole('dialog',{name:'Highlights',exact:true}).getByRole('button',{name:'View story by '+owner.username,exact:true})).toBeVisible();await owner.page.screenshot({path:info.outputPath('live-highlights.png'),fullPage:true});
  expect((await owner.page.request.delete('/api/social/tools/close-friends/'+member.id,{headers})).ok()).toBe(true);expect((await member.page.request.post('/api/social/stories/'+story.id+'/view',{headers})).status()).toBe(403);
  await owner.page.goto('/');const base64=await owner.page.evaluate(async()=>{const stream=await navigator.mediaDevices.getUserMedia({video:true});try{const recorder=new MediaRecorder(stream,{mimeType:'video/webm'}),chunks:Blob[]=[];recorder.ondataavailable=e=>chunks.push(e.data);const complete=new Promise<Blob>(resolve=>{recorder.onstop=()=>resolve(new Blob(chunks,{type:'video/webm'}));});recorder.start();await new Promise(resolve=>setTimeout(resolve,900));recorder.stop();const bytes=new Uint8Array(await(await complete).arrayBuffer());let binary='';for(const byte of bytes)binary+=String.fromCharCode(byte);return btoa(binary);}finally{stream.getTracks().forEach(track=>track.stop());}});
  const videoResponse=await owner.page.request.post('/api/social/reels',{headers,multipart:{caption:'Synthetic video '+owner.username,audience:'PUBLIC',file:{name:'synthetic.webm',mimeType:'video/webm',buffer:Buffer.from(base64,'base64')}}});expect(videoResponse.ok()).toBe(true);const video=await videoResponse.json();postId=video.id;
  for(const name of ['Learning','Weekend'])expect((await owner.page.request.post('/api/social/tools/collections/'+video.id,{headers,data:{name}})).ok()).toBe(true);
  const saved=await(await owner.page.request.get('/api/social/tools/collections/posts?name=Learning')).json();expect(saved.items.some((p:{id:number})=>p.id===video.id)).toBe(true);
  await owner.page.goto('/reels');const card=owner.page.locator('.reel-card').filter({hasText:'Synthetic video '+owner.username});await expect.poll(()=>card.locator('video').evaluate((node:HTMLVideoElement)=>node.readyState),{timeout:25_000}).toBeGreaterThanOrEqual(2);await card.getByRole('button',{name:'Like (0)',exact:true}).click();await expect(card.getByRole('button',{name:'Unlike (1)',exact:true})).toBeVisible();await owner.page.screenshot({path:info.outputPath('live-reels.png'),fullPage:true});expect(await owner.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 }finally{
  const owner=accounts[0];if(owner){if(postId)expect((await owner.page.request.delete('/api/social/posts/'+postId,{headers})).status()).toBe(204);if(storyId)expect((await owner.page.request.delete('/api/social/stories/'+storyId,{headers})).status()).toBe(204);}
  for(const context of contexts)await context.close();
 }
});
