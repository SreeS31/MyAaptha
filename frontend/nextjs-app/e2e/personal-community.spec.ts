import {test,expect,Page} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
test.use({permissions:['camera'],launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required']}});
async function mount(page:Page,emptyFeed=false){
 await page.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
 const post={id:1,authorUserId:1,authorName:'Alex',caption:'Learning together',audience:'PUBLIC',mine:true,createdAt:new Date().toISOString(),updatedAt:new Date().toISOString(),likeCount:0,commentCount:0,likedByMe:false,savedByMe:true,comments:[]};
 let story={id:10,authorUserId:1,authorName:'Alex',caption:'A text story',audience:'CLOSE_FRIENDS',mediaUrl:null,mediaType:'text/plain',createdAt:new Date().toISOString(),expiresAt:new Date(Date.now()+86400000).toISOString(),viewCount:0,viewedByMe:false,mine:true,highlightName:null as string|null};
 const poll={id:1,kind:'POLL',title:'Weekend ride',details:'Choose a time',location:'',multiple:false,closed:false,canManage:true,options:[{id:11,label:'Morning',count:0,selected:false},{id:12,label:'Evening',count:0,selected:false}],responses:{}};
 const event={id:2,kind:'EVENT',title:'Club meetup',details:'Bring a friend',location:'Club house',startsAt:new Date(Date.now()+86400000).toISOString(),endsAt:null,multiple:false,closed:false,canManage:true,options:[],responses:{} as Record<string,number>,myResponse:null as string|null};
 const friends=new Set([2]);let upload='';let video=Buffer.alloc(0);
 await page.route('**/api/**',async route=>{
  const request=route.request(),path=new URL(request.url()).pathname,method=request.method();let value:unknown=[];
  if(path==='/api/auth/me')value={id:1,username:'Alex',role:'USER'};
  else if(path==='/api/settings/me')value={};
  else if(path.includes('unread'))value={count:0};
  else if(path==='/api/network/chats/workspace')value=[];
  else if(path.startsWith('/api/network/chats/workspace/'))value={favourite:false,theme:'DEFAULT',canManage:true,creator:true,solo:false,listName:''};
  else if(path==='/api/network/circles')value=[{id:9,name:'Cyclists',description:'Local rides',members:[{person:{id:1,displayName:'Alex'},admin:true,creator:true}],currentUserAdmin:true,currentUserCanPost:true,ownedByCurrentUser:true,postingPermission:'ALL_MEMBERS'}];
  else if(path==='/api/network/relationships')value=[{id:1,type:'Friend',person:{id:2,displayName:'Sam',accountStatus:'ACTIVE',identityType:'ACCOUNT'}}];
  else if(path==='/api/network/chats/circles')value=[{circleId:9,displayName:'Cyclists',lastMessage:'Welcome',lastMessageAt:new Date().toISOString(),unreadCount:0}];
  else if(path.includes('/presence/'))value={online:true,typingUsers:[]};
  else if(path==='/api/network/circles/9/activities')value={items:[poll,event],hasNext:false,nextBefore:2};
  else if(path.endsWith('/activities/1/vote')){const ids=request.postDataJSON().optionIds as number[];poll.options=poll.options.map(o=>({...o,selected:ids.includes(o.id),count:ids.includes(o.id)?1:0}));value=poll;}
  else if(path.endsWith('/activities/2/rsvp')){event.myResponse=request.postDataJSON().response;event.responses={[event.myResponse!]:1};value=event;}
  else if(path==='/api/social/feed'||path==='/api/social/saved')value=emptyFeed?[]:[post];
  else if(path==='/api/social/posts/1')value=post;
  else if(path==='/api/social/stories'&&method==='POST'){upload=request.postDataBuffer()?.toString()||'';value=story;}
  else if(path==='/api/social/stories')value=[story];
  else if(path==='/api/social/tools/archive'||path==='/api/social/tools/highlights')value=[story];
  else if(path==='/api/social/tools/close-friends')value=Array.from(friends,id=>({id,name:'Sam'}));
  else if(path.startsWith('/api/social/tools/close-friends/')){const id=Number(path.split('/').pop());if(method==='DELETE')friends.delete(id);else friends.add(id);value={};}
  else if(path.endsWith('/highlight')){story={...story,highlightName:request.postDataJSON().name};value=story;}
  else if(path.endsWith('/reactions'))value={counts:{},mine:null};
  else if(path.endsWith('/viewers'))value=[{id:2,name:'Sam'}];
  else if(path==='/api/social/tools/collections')value=[{name:'Learning',count:1}];
  else if(path==='/api/social/tools/collections/posts')value={items:[post],hasNext:false,nextBefore:1};
  else if(path==='/api/social/browse')value={items:[{...post,id:20,mediaUrl:'/api/social/posts/20/media',mediaType:'video/webm'}],hasNext:false,nextBefore:20};
  else if(path==='/api/social/posts/20/media'){await route.fulfill({body:video,contentType:'video/webm'});return;}
  else if(path==='/api/social/posts/20/like')value={...post,id:20,likedByMe:true,likeCount:1,mediaUrl:'/api/social/posts/20/media',mediaType:'video/webm'};
  await route.fulfill({json:value});
 });
 return {friends,upload:()=>upload,setVideo:(bytes:Buffer)=>{video=bytes;}};
}
test('circle poll votes and event RSVPs use the shared activity API',async({page},info)=>{
 await mount(page);await page.goto('/messages?circle=9');await page.getByLabel('Circle options',{exact:true}).click();await page.getByRole('button',{name:'Polls & events',exact:true}).click();const pane=page.getByRole('dialog',{name:'Circle polls and events'});await expect(pane).toBeVisible();await pane.getByLabel('Morning',{exact:false}).click();await expect(pane.getByText('1 votes',{exact:true})).toBeVisible();await pane.getByRole('button',{name:'Clear my vote',exact:true}).click();await expect(pane.getByLabel('Morning',{exact:false})).not.toBeChecked();await pane.getByRole('button',{name:'Going (0)',exact:true}).click();await expect(pane.getByRole('button',{name:'Going (1)',exact:true})).toHaveAttribute('aria-pressed','true');expect((await new AxeBuilder({page}).include('dialog').withTags(['wcag2a','wcag2aa']).analyze()).violations).toEqual([]);await page.screenshot({path:info.outputPath('polls-events.png'),fullPage:true});
});
test('Close Friends and collections remain usable on mobile and desktop',async({page},info)=>{
 const server=await mount(page);await page.goto('/online-feed');await page.getByRole('button',{name:'Close Friends',exact:true}).click();const friends=page.getByRole('dialog',{name:'Close Friends',exact:true});await friends.getByLabel('Sam',{exact:true}).click();await expect.poll(()=>server.friends.has(2)).toBe(false);await friends.getByLabel('Sam',{exact:true}).click();await expect.poll(()=>server.friends.has(2)).toBe(true);await friends.getByRole('button',{name:'Close',exact:true}).click();await page.getByRole('button',{name:'Collections',exact:true}).click();const collections=page.getByRole('dialog',{name:'Collections',exact:true});await collections.getByRole('button',{name:'Learning (1)',exact:true}).click();await expect(collections.getByRole('link',{name:'Learning together',exact:true})).toBeVisible();expect((await new AxeBuilder({page}).include('dialog').withTags(['wcag2a','wcag2aa']).analyze()).violations).toEqual([]);await page.screenshot({path:info.outputPath('collections.png'),fullPage:true});
});
test('text story supports explicit archive choice and highlights',async({page},info)=>{
 const server=await mount(page);await page.goto('/online-feed');await page.locator('summary').filter({hasText:'Add a story'}).click();await page.getByLabel('Caption',{exact:true}).fill('A text story');await page.getByLabel('Story audience',{exact:true}).selectOption('CLOSE_FRIENDS');await page.getByRole('checkbox',{name:'Keep a private archive for 30 days after expiry',exact:true}).check();await page.getByRole('button',{name:'Share story',exact:true}).click();await expect.poll(()=>server.upload()).toContain('archive');await page.getByRole('button',{name:'View story by Alex',exact:true}).click();const story=page.getByRole('dialog',{name:'Story by Alex',exact:true});await expect(story.getByText('A text story',{exact:true})).toBeVisible();await story.getByRole('button',{name:'Viewers (0)',exact:true}).click();await expect(story.getByRole('list',{name:'Story viewers'}).getByText('Sam',{exact:true})).toBeVisible();page.once('dialog',d=>d.accept('Family'));await story.getByRole('button',{name:'Add to highlights',exact:true}).click();await expect(story.getByRole('button',{name:'Edit highlight',exact:true})).toBeVisible();await page.screenshot({path:info.outputPath('text-story.png'),fullPage:true});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});
test('Reels plays an authenticated synthetic video with working like controls',async({page},info)=>{
 const server=await mount(page);await page.goto('/');const base64=await page.evaluate(async()=>{const stream=await navigator.mediaDevices.getUserMedia({video:true});try{const recorder=new MediaRecorder(stream,{mimeType:'video/webm'}),chunks:Blob[]=[];recorder.ondataavailable=e=>chunks.push(e.data);const complete=new Promise<Blob>(resolve=>{recorder.onstop=()=>resolve(new Blob(chunks,{type:'video/webm'}));});recorder.start();await new Promise(resolve=>setTimeout(resolve,700));recorder.stop();const bytes=new Uint8Array(await (await complete).arrayBuffer());let binary='';for(const byte of bytes)binary+=String.fromCharCode(byte);return btoa(binary);}finally{stream.getTracks().forEach(t=>t.stop());}});server.setVideo(Buffer.from(base64,'base64'));await page.goto('/reels');await expect(page.getByRole('heading',{name:'Reels',exact:true})).toBeVisible();await expect.poll(()=>page.locator('video').evaluate((node:HTMLVideoElement)=>node.readyState)).toBeGreaterThanOrEqual(2);await page.getByRole('button',{name:'Like (0)',exact:true}).click();await expect(page.getByRole('button',{name:'Unlike (1)',exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);await page.screenshot({path:info.outputPath('reels.png'),fullPage:true});
});

test('saved post links retrieve older posts outside the current feed',async({page})=>{await mount(page,true);await page.goto('/feed?postId=1');await expect(page.locator('#feed-post-1').getByText('Learning together',{exact:true})).toBeVisible();});
