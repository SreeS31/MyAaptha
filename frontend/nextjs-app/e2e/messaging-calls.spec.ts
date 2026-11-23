import {test,expect,Browser,BrowserContext} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.use({launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required']},permissions:['microphone','camera']});

function fixture(initialMembers=2){
 let created=false,ended=false,sequence=0;let scope='DIRECT',target=2,mode='AUDIO',creator=1;
 const members=new Map<number,string>(),signals:{id:number;senderId:number;recipientId:number;type:string;payload:string}[]=[];
 let circle={id:9,name:'Cycling circle',description:'Weekend rides',ownerName:'Member 1',ownedByCurrentUser:true,currentUserAdmin:true,currentUserCanPost:true,postingPermission:'ALL_MEMBERS',members:Array.from({length:initialMembers},(_,i)=>i+1).map(id=>({person:{id,displayName:`Member ${id}`,accountStatus:'ACTIVE'},creator:id===1,admin:id===1}))};
 const room=(user:number)=>({id:'fixture-call',scope,targetId:target,creatorId:creator,name:scope==='CIRCLE'?circle.name:`Member ${user===creator?target:creator}`,callType:mode,createdAt:new Date().toISOString(),ended,currentUserId:user,capacity:8,members:Array.from(members,([userId,status])=>({userId,name:`Member ${userId}`,status}))});
 let uploaded='';const preferences=new Map<number,Record<string,unknown>>();
 async function mount(context:BrowserContext,user:number){
  await context.addInitScript(()=>{const Native=window.RTCPeerConnection;const peers:RTCPeerConnection[]=[];(window as unknown as {testCallPeers:RTCPeerConnection[]}).testCallPeers=peers;window.RTCPeerConnection=class extends Native{constructor(configuration?:RTCConfiguration){super(configuration);peers.push(this);}};});
  await context.addInitScript(()=>localStorage.setItem('myaaptha.web-session.metadata',JSON.stringify({expiresIn:3600,receivedAtEpochMs:Date.now(),expiresAtEpochMs:Date.now()+3600000})));
  await context.route('**/api/**',async route=>{
   const request=route.request(),url=new URL(request.url()),path=url.pathname,method=request.method();let data:unknown=[];
   if(path==='/api/auth/me')data={id:user,username:`Member ${user}`,role:'USER'};
   else if(path==='/api/network/chats/workspace')data=preferences.has(user)?[{kind:'CIRCLE',targetId:9,...preferences.get(user)}]:[];
   else if(path.startsWith('/api/network/chats/workspace/')){const previous=preferences.get(user)||{favourite:false,archived:false,mutedUntil:null,theme:'DEFAULT',listName:'',disappearingSeconds:0,canManage:user===1,creator:user===1};if(method==='PUT'){preferences.set(user,{...previous,...request.postDataJSON()});}data=path.endsWith('/export')?[{id:100,message:'Sunday ride at 7 am?'}]:preferences.get(user)||previous;}
   else if(path==='/api/network/calls/ice')data={iceServers:[],relayConfigured:false,credentialsExpireAt:null};
   else if(path==='/api/network/meetings'&&method==='POST'){const value=request.postDataJSON();scope=value.scope;target=value.targetId;mode=value.callType;created=true;ended=false;creator=user;members.set(user,'JOINED');data=room(user);}
   else if(path==='/api/network/meetings'||path==='/api/network/meetings/history')data=created&&!ended?[room(user)]:[];
   else if(path.startsWith('/api/network/meetings/fixture-call')){
    if(path.endsWith('/join')){members.set(user,'JOINED');data=room(user);}
    else if(path.endsWith('/end')){ended=true;data={};}
    else if(path.endsWith('/leave')){members.set(user,'LEFT');if(scope==='DIRECT')ended=true;data={};}
    else if(path.endsWith('/signals')&&method==='POST'){const value=request.postDataJSON();signals.push({id:++sequence,senderId:user,...value});data={};}
    else if(path.endsWith('/signals'))data=signals.filter(value=>value.recipientId===user&&value.id>Number(url.searchParams.get('after')||0));
    else data=room(user);
   }
   else if(path==='/api/network/messages/conversations')data=[{userId:user===1?2:1,displayName:`Member ${user===1?2:1}`,lastMessage:'See you on Sunday!',lastMessageAt:new Date().toISOString(),unreadCount:0}];
   else if(path==='/api/network/chats/circles')data=[{circleId:9,displayName:circle.name,lastMessage:'See you on Sunday!',lastMessageAt:new Date().toISOString(),unreadCount:2}];
   else if(path==='/api/network/circles/9/posts')data=[{id:100,authorId:2,authorName:'Member 2',message:'Sunday ride at 7 am?',createdAt:new Date().toISOString(),currentUserAuthor:user===2,reactions:{}},{id:101,authorId:1,authorName:'Member 1',message:'Yes! Meet at the park.',createdAt:new Date().toISOString(),currentUserAuthor:user===1,reactions:{}}];
   else if(path==='/api/network/circles')data=[circle];
   else if(path==='/api/network/circles/9'&&method==='PUT'){circle={...circle,...request.postDataJSON()};data=circle;}
   else if(path==='/api/network/circles/9/members'&&method==='POST'){const id=request.postDataJSON().userId;circle={...circle,members:[...circle.members,{person:{id,displayName:`Member ${id}`,accountStatus:'ACTIVE'},creator:false,admin:false}]};data=circle;}
   else if(path.match(/\/api\/network\/circles\/9\/admins\/\d+$/)){const id=Number(path.split('/').pop());circle={...circle,members:circle.members.map(m=>m.person.id===id?{...m,admin:method==='POST'}:m)};data=circle;}
   else if(path==='/api/network/relationships')data=[{id:3,type:'Friend',person:{id:3,displayName:'Member 3',accountStatus:'ACTIVE'}}];
   else if(path==='/api/uploads/policy')data={level:{id:1,name:'Free',storageBytes:1073741824,uploadBytes:26214400,maxRetentionDays:3650,allowNever:true},usedBytes:0,retentionDaysOptions:[0,7,365],defaultRetentionDays:0};
   else if(path.includes('unread'))data={count:0};
   else if(path.includes('preferences'))data={readReceipts:true};
   else if(path.includes('/presence/'))data={online:true,typingUsers:[]};
   else if(path.includes('/messages/with/')&&method==='POST'){uploaded=request.postDataBuffer()?.toString()||'';data={id:1,senderId:user,senderName:`Member ${user}`,message:'',currentUserAuthor:true,createdAt:new Date().toISOString(),attachmentUrl:null};}
   await route.fulfill({json:data});
  });
 }
 return {mount,uploaded:()=>uploaded};
}

for(const scope of ['DIRECT','CIRCLE'] as const)test(`${scope==='DIRECT'?'individual voice':'three-person circle video'} call connects real browser media and releases devices`,async({browser},info)=>{
 test.setTimeout(120_000);const server=fixture(scope==='CIRCLE'?3:2),contexts:BrowserContext[]=[],pages=[];
 try{
  for(let index=1;index<=(scope==='CIRCLE'?3:2);index++){const user=scope==='DIRECT'?3-index:index;const context=await browser.newContext({baseURL:info.project.use.baseURL,permissions:['microphone','camera'],viewport:info.project.use.viewport});contexts.push(context);await server.mount(context,user);const page=await context.newPage();pages.push(page);await page.goto(scope==='CIRCLE'?'/messages?circle=9':`/messages?person=${user===1?2:1}`);}
  await pages[0].bringToFront();await pages[0].getByRole('button',{name:scope==='CIRCLE'?'Video call':'Voice call',exact:true}).click();
  await expect(pages[0].getByRole('dialog')).toBeVisible();
  for(const page of pages.slice(1)){await page.bringToFront();await page.getByRole('complementary',{name:'Active calls'}).getByRole('button',{name:scope==='CIRCLE'?'Join call':'Answer',exact:true}).click();await expect(page.getByRole('dialog')).toBeVisible();}
  for(const page of pages){await expect.poll(()=>page.locator('dialog video').evaluateAll(nodes=>nodes.filter(node=>{const stream=(node as HTMLVideoElement).srcObject as MediaStream|null;return stream?.getAudioTracks().some(track=>track.readyState==='live');}).length),{timeout:30_000}).toBe(pages.length);}
  for(const page of pages)await expect.poll(()=>page.evaluate(async()=>{const peers=(window as unknown as {testCallPeers:RTCPeerConnection[]}).testCallPeers;if(!peers.length||peers.some(peer=>peer.connectionState!=='connected'))return false;let received=0;for(const peer of peers){const stats=await peer.getStats();stats.forEach(value=>{if(value.type==='inbound-rtp')received+=value.bytesReceived||0;});}return received>0;}),{timeout:30_000}).toBe(true);
  await pages[0].bringToFront();await pages[0].getByRole('button',{name:'Mute',exact:true}).click();await expect(pages[0].getByRole('button',{name:'Unmute',exact:true})).toBeVisible();
  expect(await pages[0].locator('dialog video').first().evaluate(node=>(node as HTMLVideoElement).srcObject instanceof MediaStream&&((node as HTMLVideoElement).srcObject as MediaStream).getAudioTracks().every(track=>!track.enabled))).toBe(true);
  for(const page of pages)await page.evaluate(()=>{(window as unknown as {testCallTracks:MediaStreamTrack[]}).testCallTracks=Array.from(document.querySelectorAll('dialog video')).flatMap(node=>((node as HTMLVideoElement).srcObject as MediaStream)?.getTracks()||[]);});
  await pages[0].screenshot({path:info.outputPath(`${scope.toLowerCase()}-call.png`),fullPage:true});
  await pages[0].getByRole('button',{name:scope==='CIRCLE'?'End for everyone':'Leave call',exact:true}).click();
  for(const page of pages){await expect(page.getByRole('dialog')).toHaveCount(0);await expect.poll(()=>page.evaluate(()=>(window as unknown as {testCallTracks:MediaStreamTrack[]}).testCallTracks.every(track=>track.readyState==='ended'))).toBe(true);}
 }finally{for(const context of contexts)await context.close();}
});

test('circle info manages real API fields and voice notes are reviewed before send',async({page,context},info)=>{
 const server=fixture();await server.mount(context,1);await page.goto('/messages?circle=9');
 await page.getByRole('button',{name:'Circle info',exact:true}).click();const pane=page.getByRole('complementary',{name:'Circle info'});await expect(pane).toBeVisible();
 await pane.getByRole('button',{name:'Add member',exact:true}).click();await pane.getByRole('button',{name:'+ Member 3',exact:true}).click();await expect(pane.getByRole('heading',{name:'3 members',exact:true})).toBeVisible();
 await pane.getByRole('button',{name:'Edit circle',exact:true}).click();await pane.getByLabel('Circle name',{exact:true}).fill('Hyderabad cyclists');await pane.getByRole('button',{name:'Save',exact:true}).click();await expect(pane.getByRole('heading',{name:'Hyderabad cyclists',exact:true})).toBeVisible();
 await pane.evaluate(node=>{node.scrollTop=0;});
 await page.screenshot({path:info.outputPath('messaging-circle-info.png'),fullPage:true});
 expect((await new AxeBuilder({page}).include('main').withTags(['wcag2a','wcag2aa']).analyze()).violations).toEqual([]);
 await page.goto('/messages?person=2');await page.getByRole('button',{name:'Record voice note'}).click();await expect(page.getByRole('status').filter({hasText:'Recording 0:01'})).toBeVisible();await page.getByRole('button',{name:'Stop voice recording'}).click();
 await expect(page.getByLabel('Voice note preview')).toBeVisible();expect(server.uploaded()).toBe('');await page.getByRole('button',{name:'Send message',exact:true}).click();await page.getByRole('dialog',{name:'Keep this attachment',exact:true}).getByRole('button',{name:'Continue upload',exact:true}).click();await expect.poll(()=>server.uploaded()).toContain('voice-note-');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});


test('circle options expose members, admins, themes, lists, timers and safe history controls',async({page,context},info)=>{
 const server=fixture();await server.mount(context,1);await page.goto('/messages?circle=9');
 const menu=page.getByLabel('Circle options',{exact:true});await menu.click();
 for(const name of ['Add member','Circle info','Search','Select messages','Mute notifications','Disappearing messages','Chat theme','Add to favourites','Add to list','Export chat','Close chat','Clear chat','Exit circle'])await expect(page.locator('.chat-thread-options').getByRole('button',{name,exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Add member',exact:true}).click();const pane=page.getByRole('complementary',{name:'Circle info'});await pane.getByRole('button',{name:'+ Member 3',exact:true}).click();
 await pane.getByLabel('Actions for Member 3',{exact:true}).click();await pane.getByRole('button',{name:'Make admin',exact:true}).click();await expect(pane.getByText('Admin',{exact:true})).toBeVisible();await pane.getByRole('button',{name:'Close circle info',exact:true}).click();
 await menu.click();await page.getByRole('button',{name:'Chat theme',exact:true}).click();let dialog=page.getByRole('dialog',{name:'Chat options'});await dialog.getByRole('button',{name:'Ocean',exact:true}).click();await expect(page.locator('.chat-theme-ocean')).toBeVisible();
 await menu.click();await page.getByRole('button',{name:'Add to list',exact:true}).click();dialog=page.getByRole('dialog',{name:'Chat options'});await dialog.getByLabel('List name',{exact:true}).fill('College friends');await dialog.getByRole('button',{name:'Save',exact:true}).click();await expect(page.locator('.chat-inbox-filters button').filter({hasText:'College friends'})).toHaveCount(1);
 await menu.click();await page.getByRole('button',{name:'Disappearing messages',exact:true}).click();await page.getByRole('dialog').getByRole('button',{name:'7 days',exact:true}).click();
 await menu.click();await page.getByRole('button',{name:'Select messages',exact:true}).click();await page.getByLabel('Select message 100',{exact:true}).check();await expect(page.getByText('1 selected',{exact:true})).toBeVisible();await page.getByRole('button',{name:'Cancel selection',exact:true}).click();
 await menu.click();await page.getByRole('button',{name:'Clear chat',exact:true}).click();await expect(page.getByRole('dialog').getByText('Remove the existing history for you. Other members keep their messages.')).toBeVisible();await page.getByRole('dialog').getByRole('button',{name:'Cancel',exact:true}).click();await expect(page.getByText('Sunday ride at 7 am?',{exact:true})).toBeVisible();
 await page.screenshot({path:info.outputPath('circle-options.png'),fullPage:true});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
});
