import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';

test('failed, cancelled and ended calls release synthetic devices immediately',async({page,playwright})=>{
 test.setTimeout(180000);page.setDefaultTimeout(15000);
 await page.addInitScript(()=>{
  const state:any={streams:[],peers:[],pending:[],defer:false};(window as any).__callTest=state;
  const capture=(constraints:any)=>{const context=new AudioContext(),stream=context.createMediaStreamDestination().stream;
   if(constraints.video){const canvas=document.createElement('canvas');canvas.width=2;canvas.height=2;for(const track of canvas.captureStream().getVideoTracks())stream.addTrack(track);}
   for(const track of stream.getTracks()){const stop=track.stop.bind(track);track.stop=()=>{stop();if(stream.getTracks().every(t=>t.readyState==='ended'))void context.close();};}
   state.streams.push(stream);return stream;};
  Object.defineProperty(navigator.mediaDevices,'getUserMedia',{configurable:true,value:(constraints:any)=>state.defer?new Promise(resolve=>state.pending.push(()=>resolve(capture(constraints)))):Promise.resolve(capture(constraints))});
  (window as any).RTCPeerConnection=class{iceGatheringState='complete';connectionState='new';localDescription:any=null;ontrack:any=null;onconnectionstatechange:any=null;closed=false;
   constructor(configuration:any){(this as any).configuration=configuration;state.peers.push(this);}addTrack(){}async setRemoteDescription(){}async createOffer(){return{type:'offer',sdp:'synthetic'};}async createAnswer(){return{type:'answer',sdp:'synthetic'};}async setLocalDescription(value:any){this.localDescription=value;}close(){this.closed=true;this.connectionState='closed';}};
 });
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});const username=`call-cleanup-${randomUUID().slice(0,8)}`,password=`Fixture-${randomUUID()}`;
 let holdIce=false,releaseIce:(()=>void)|undefined;
 let exposeIncoming=false,failAccept=true,holdEnd=false,releaseEnd:(()=>void)|undefined,accepts=0,ends=0;
 const call={id:9001,callerId:9002,recipientId:9003,callerName:'Synthetic caller',recipientName:'Synthetic recipient',callType:'VIDEO',status:'RINGING',offerSdp:JSON.stringify({type:'offer',sdp:'synthetic'}),currentUserCaller:false,createdAt:'2026-10-21T00:00:00Z',updatedAt:'2026-10-21T00:00:00Z'};
 await page.route('**/api/network/calls/ice',async route=>{if(holdIce)await new Promise<void>(resolve=>{releaseIce=resolve;});await route.fulfill({json:{iceServers:[{urls:['turn:relay.test:3478'],username:'synthetic',credential:'temporary-test'}],relayConfigured:true,credentialsExpireAt:4102444800}});});
 await page.route('**/api/network/calls/incoming',route=>route.fulfill({json:exposeIncoming?[call]:[]}));
 await page.route('**/api/network/calls/9001',route=>route.fulfill({json:call}));
 await page.route('**/api/network/calls/9001/accept',async route=>{accepts++;await route.fulfill(failAccept?{status:503,json:{message:'Synthetic signaling unavailable'}}:{json:{...call,status:'ACCEPTED',answerSdp:JSON.stringify({type:'answer',sdp:'synthetic'})}});});
 await page.route('**/api/network/calls/9001/end',async route=>{ends++;if(holdEnd)await new Promise<void>(resolve=>{releaseEnd=resolve;});await route.fulfill({json:{...call,status:'ENDED'}});});
 await page.route('**/api/network/calls/9001/reject',route=>route.fulfill({json:{...call,status:'REJECTED'}}));
 const stopped=()=>page.evaluate(()=>{const data=(window as any).__callTest;return data.streams.length>0&&data.streams.every((s:MediaStream)=>s.getTracks().every(t=>t.readyState==='ended'))&&data.peers.every((p:any)=>p.closed);});
 try{
  expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1868${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
  await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/,{timeout:15000});
  await page.goto('/dashboard?callId=9001');await page.getByRole('button',{name:'Accept',exact:true}).click();await expect(page.getByRole('dialog').getByRole('alert')).toContainText('Synthetic signaling unavailable');await expect.poll(stopped).toBe(true);await expect(page.getByRole('button',{name:'Accept',exact:true})).toBeEnabled();
  await page.getByRole('button',{name:'Decline',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);
  // Permission can resolve after the user has cancelled the preparation dialog.
  await page.goto('/dashboard?callId=9001');await page.evaluate(()=>{(window as any).__callTest.defer=true;});const before=accepts;
  await page.getByRole('button',{name:'Accept',exact:true}).click();await expect.poll(()=>page.evaluate(()=>(window as any).__callTest.pending.length)).toBe(1);
  await page.getByRole('button',{name:'End call',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.evaluate(()=>{for(const resolve of (window as any).__callTest.pending.splice(0))resolve();});await expect.poll(stopped).toBe(true);expect(accepts).toBe(before);
  // Relay configuration can also resolve after cancellation: release capture immediately.
  await page.evaluate(()=>{(window as any).__callTest.defer=false;});holdIce=true;
  await page.goto('/dashboard?callId=9001');await page.getByRole('button',{name:'Accept',exact:true}).click();
  await expect.poll(()=>typeof releaseIce).toBe('function');
  await page.getByRole('button',{name:'End call',exact:true}).click();await expect.poll(stopped).toBe(true);
  releaseIce!();holdIce=false;await expect(page.getByRole('dialog')).toHaveCount(0);expect(accepts).toBe(before);
  // Ending a connected call must release devices before a slow end request completes.
  failAccept=false;await page.goto('/dashboard?callId=9001');await page.getByRole('button',{name:'Accept',exact:true}).click();await expect(page.getByText('Connected',{exact:true})).toBeVisible();expect(await page.evaluate(()=>(window as any).__callTest.peers.every((peer:any)=>peer.configuration.iceServers[0].urls[0]==='turn:relay.test:3478'))).toBe(true);holdEnd=true;
  await page.getByRole('button',{name:'End call',exact:true}).click();await expect.poll(()=>typeof releaseEnd).toBe('function');await expect.poll(stopped).toBe(true);await expect(page.getByRole('dialog')).toHaveCount(0);releaseEnd!();holdEnd=false;
  // A client-side navigation must release the same devices without unloading the document.
  exposeIncoming=true;await page.goto('/settings');
  const menu=page.getByRole('button',{name:'Toggle main menu'});if((page.viewportSize()?.width||1280)<=760){await expect(menu).toHaveAttribute('aria-expanded','false');await menu.click();await expect(menu).toHaveAttribute('aria-expanded','true');}
  const marker=await page.evaluate(()=>{(window as any).__callTest.marker=String(Math.random());return (window as any).__callTest.marker;});
  await page.locator('#workspace-navigation a[href="/dashboard"]').click();await expect(page).toHaveURL(/dashboard/,{timeout:15000});
  await page.getByRole('button',{name:'Accept',exact:true}).click();await expect(page.getByText('Connected',{exact:true})).toBeVisible();
  const endsBeforeNavigation=ends;await page.goBack();await expect(page).toHaveURL(/settings/);expect(await page.evaluate(()=>(window as any).__callTest.marker)).toBe(marker);await expect.poll(stopped).toBe(true);await expect.poll(()=>ends).toBeGreaterThan(endsBeforeNavigation);

 }finally{releaseIce?.();releaseEnd?.();await api.dispose();}
});
