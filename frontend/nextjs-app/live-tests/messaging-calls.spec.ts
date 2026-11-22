import {test,expect,BrowserContext,Page} from '@playwright/test';
import {randomBytes} from 'node:crypto';
import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

test.skip(process.env.MYAAPTHA_LIVE_WRITE_TESTS!=='1','Explicit removable synthetic-account test opt-in required');
test.skip(process.env.MYAAPTHA_LIVE_RELAY_TESTS!=='1','Explicit approved relay-network test opt-in required');
test.use({launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required']}});

type Identity={id:number;username:string;page:Page};
for(const mode of ['direct-tls','circle-udp'] as const)test(`live ${mode} call carries real media exclusively through the approved relay`,async({browser},info)=>{
 test.setTimeout(240_000);const contexts:BrowserContext[]=[],accounts:Identity[]=[];
 try{
  for(let index=0;index<(mode==='circle-udp'?3:2);index++){
   const context=await browser.newContext({baseURL:info.project.use.baseURL,permissions:['microphone','camera'],viewport:info.project.use.viewport,isMobile:info.project.use.isMobile,hasTouch:info.project.use.hasTouch,userAgent:info.project.use.userAgent,deviceScaleFactor:info.project.use.deviceScaleFactor});contexts.push(context);
   await context.addInitScript(()=>{const Original=window.RTCPeerConnection;const peers:RTCPeerConnection[]=[];(window as unknown as {syntheticCallPeers:RTCPeerConnection[]}).syntheticCallPeers=peers;window.RTCPeerConnection=class extends Original{constructor(configuration?:RTCConfiguration){super({...configuration,iceTransportPolicy:'relay'});peers.push(this);}};});
   await context.route('**/api/network/calls/ice',async route=>{
    const response=await route.fetch();expect(response.ok()).toBe(true);const value=await response.json();expect(value.relayConfigured).toBe(true);
    const servers=value.iceServers.map((server:RTCIceServer)=>({...server,urls:(Array.isArray(server.urls)?server.urls:[server.urls]).filter(url=>mode==='direct-tls'?url.startsWith('turns:'):url.startsWith('turn:')&&url.endsWith('transport=udp'))})).filter((server:RTCIceServer)=>Array.isArray(server.urls)&&server.urls.length>0);
    expect(servers.length).toBeGreaterThan(0);await route.fulfill({response,json:{...value,iceServers:servers}});
   });
   const page=await context.newPage(),username='msg22'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('base64url');
   const registered=await page.request.post('/api/users',{data:{username,password,phoneNumber:'+1999'+String(parseInt(randomBytes(5).toString('hex'),16)%10000000000).padStart(10,'0')}});expect(registered.ok()).toBe(true);const user=await registered.json();
   const file=resolve(__dirname,'../../../.tools/messaging-live-fixtures-20261122.json');const fixtures=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{accounts:[]};fixtures.accounts.push({id:user.id,username});writeFileSync(file,JSON.stringify(fixtures,null,2));accounts.push({id:user.id,username,page});
   await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).not.toHaveURL(/\/auth$/);
  }
  const owner=accounts[0],headers={'X-MyAaptha-Web':'1','Origin':new URL(owner.page.url()).origin};
  for(const member of accounts.slice(1))expect((await owner.page.request.post('/api/network/relationships',{headers,data:{relatedUserId:member.id,type:'Friend',visibilityScope:'FRIENDS'}})).ok()).toBe(true);
  let circleId:number|undefined;
  if(mode==='circle-udp'){const response=await owner.page.request.post('/api/network/chats/groups',{headers,data:{name:'Synthetic relay circle '+owner.username,memberIds:accounts.slice(1).map(member=>member.id)}});expect(response.ok()).toBe(true);circleId=(await response.json()).id;}
  for(const member of accounts)await member.page.goto(circleId?`/messages?circle=${circleId}`:`/messages?person=${member.id===owner.id?accounts[1].id:owner.id}`);
  await owner.page.bringToFront();await owner.page.getByRole('button',{name:circleId?'Video call':'Voice call',exact:true}).click();await expect(owner.page.getByRole('dialog')).toBeVisible();
  for(const member of accounts.slice(1)){await member.page.bringToFront();await member.page.getByRole('complementary',{name:'Active calls'}).getByRole('button',{name:circleId?'Join call':'Answer',exact:true}).click();await expect(member.page.getByRole('dialog')).toBeVisible();}
  const results=[];
  for(const member of accounts){
   const stats=async()=>member.page.evaluate(async()=>{
    const peers=(window as unknown as {syntheticCallPeers:RTCPeerConnection[]}).syntheticCallPeers;let relay=true,received=0;
    for(const peer of peers){const report=await peer.getStats();let localRelay=false;report.forEach(value=>{if(value.type==='inbound-rtp')received+=value.bytesReceived||0;if(value.type==='candidate-pair'&&value.state==='succeeded'&&(value.nominated||value.selected)){const candidate=report.get(value.localCandidateId);if(candidate?.candidateType==='relay')localRelay=true;}});relay=relay&&localRelay;}
    return {peers:peers.length,connected:peers.length>0&&peers.every(peer=>peer.connectionState==='connected'),relay,received};
   });
   await expect.poll(async()=>{const value=await stats();return value.peers===accounts.length-1&&value.connected&&value.relay&&value.received>0;},{timeout:60_000}).toBe(true);
   results.push(await stats());
  }
  // Aggregate counters only: do not persist TURN credentials, SDP or network addresses.
  writeFileSync(info.outputPath('relay-acceptance.json'),JSON.stringify({transport:mode,syntheticMedia:true,results},null,2));
  await owner.page.screenshot({path:info.outputPath('live-call.png'),fullPage:true});
  await owner.page.bringToFront();await owner.page.getByRole('button',{name:circleId?'End for everyone':'Leave call',exact:true}).click();
  for(const member of accounts)await expect(member.page.getByRole('dialog')).toHaveCount(0);
  const history=await owner.page.request.get('/api/network/meetings/history');expect(history.ok()).toBe(true);expect((await history.json()).some((call:{ended:boolean})=>call.ended)).toBe(true);
 }finally{
  for(const member of accounts){try{for(const room of await (await member.page.request.get('/api/network/meetings')).json())await member.page.request.post(`/api/network/meetings/${room.id}/leave`,{headers:{'X-MyAaptha-Web':'1','Origin':new URL(member.page.url()).origin},data:{}});}catch{/* Guarded fixture cleanup handles an interrupted or expired browser session. */}}
  for(const context of contexts)await context.close();
 }
});
