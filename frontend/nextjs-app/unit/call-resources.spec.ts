import {test,expect} from '@playwright/test';
import {CallResources} from '../app/lib/call-resources';
function media(){let stopped=0;return {stream:{getTracks:()=>[{stop:()=>{stopped++;}}]} as unknown as MediaStream,stops:()=>stopped};}
function peer(fail=false){let closed=0;return {connection:{ontrack:()=>{},onconnectionstatechange:()=>{},close:()=>{closed++;if(fail)throw Error('synthetic close failure');}} as unknown as RTCPeerConnection,closes:()=>closed};}
test('release immediately closes a peer and stops local and remote devices once',()=>{
 const resources=new CallResources(),local=media(),remote=media(),connection=peer(),token=resources.begin();
 resources.attachLocal(token,local.stream);resources.attachRemote(token,remote.stream);resources.attachConnection(token,connection.connection);
 resources.release();resources.release();expect(local.stops()).toBe(1);expect(remote.stops()).toBe(1);expect(connection.closes()).toBe(1);expect(resources.connection).toBeNull();expect(resources.isCurrent(token)).toBe(false);
});
test('permission resolving after cancellation is stopped rather than attached',()=>{
 const resources=new CallResources(),token=resources.begin(),late=media();resources.release();expect(resources.attachLocal(token,late.stream)).toBe(false);expect(late.stops()).toBe(1);
});
test('an old capture cannot replace or stop a newer call',()=>{
 const resources=new CallResources(),old=resources.begin(),current=resources.begin(),fresh=media(),late=media();resources.attachLocal(current,fresh.stream);expect(resources.attachLocal(old,late.stream)).toBe(false);expect(late.stops()).toBe(1);expect(fresh.stops()).toBe(0);expect(resources.isCurrent(current)).toBe(true);resources.release();expect(fresh.stops()).toBe(1);
});
test('late peer and remote-track events are closed after cancellation',()=>{
 const resources=new CallResources(),token=resources.begin(),connection=peer(),remote=media();resources.release();expect(resources.attachConnection(token,connection.connection)).toBe(false);expect(resources.attachRemote(token,remote.stream)).toBe(false);expect(connection.closes()).toBe(1);expect(remote.stops()).toBe(1);
});
test('peer shutdown failure cannot retain microphone or camera tracks',()=>{
 const resources=new CallResources(),token=resources.begin(),connection=peer(true),local=media(),remote=media();resources.attachConnection(token,connection.connection);resources.attachLocal(token,local.stream);resources.attachRemote(token,remote.stream);resources.release();expect(local.stops()).toBe(1);expect(remote.stops()).toBe(1);
});
test('replacing a remote stream stops its old tracks',()=>{
 const resources=new CallResources(),token=resources.begin(),old=media(),next=media();resources.attachRemote(token,old.stream);resources.attachRemote(token,next.stream);expect(old.stops()).toBe(1);expect(next.stops()).toBe(0);resources.release();expect(next.stops()).toBe(1);
});
