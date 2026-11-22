'use client';
import {createContext,ReactNode,useContext,useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import * as api from '../lib/meeting-api';
import {MeetingSession} from '../lib/meeting-session';
import {fetchCallIceConfiguration,hasAuthSession} from '../lib/api';

type Calling={begin:(scope:'DIRECT'|'CIRCLE',id:number,mode:'AUDIO'|'VIDEO')=>void;rooms:api.CallRoom[];join:(room:api.CallRoom)=>void;busy:boolean};
const Calls=createContext<Calling>({begin:()=>{},rooms:[],join:()=>{},busy:false});
export const useMessagingCalls=()=>useContext(Calls);
function Media({stream,muted=false,name}:{stream:MediaStream;muted?:boolean;name:string}){
 const ref=useRef<HTMLVideoElement>(null);
 useEffect(()=>{const node=ref.current;if(node){node.srcObject=stream;void node.play().catch(()=>{});}return()=>{if(node)node.srcObject=null;};},[stream]);
 return <figure><video ref={ref} autoPlay playsInline muted={muted} aria-label={name}/><figcaption>{name}</figcaption></figure>;
}
export default function MessagingCalls({children}:{children:ReactNode}){
 const [rooms,setRooms]=useState<api.CallRoom[]>([]),[room,setRoom]=useState<api.CallRoom|null>(null),[local,setLocal]=useState<MediaStream|null>(null),[remote,setRemote]=useState<Map<number,MediaStream>>(new Map()),[preparing,setPreparing]=useState(false),[error,setError]=useState(''),[muted,setMuted]=useState(false),[cameraOff,setCameraOff]=useState(false),[sharing,setSharing]=useState(false);
 const session=useRef<MeetingSession|null>(null),generation=useRef(0),screenStop=useRef<(()=>void)|null>(null),dialog=useRef<HTMLDialogElement>(null),starting=useRef(false);
 useEffect(()=>{let alive=true,busy=false;const load=async()=>{if(busy||!hasAuthSession()||document.hidden)return;busy=true;try{const values=await api.activeCalls();if(alive)setRooms(values);}catch{/* The thread displays API failures; polling resumes on the next interval. */}finally{busy=false;}};void load();const timer=setInterval(()=>void load(),5000);return()=>{alive=false;clearInterval(timer);generation.current++;screenStop.current?.();const active=session.current;active?.release();if(active)void api.leaveCall(active.room.id).catch(()=>{});};},[]);
 useEffect(()=>{if((room||preparing)&&dialog.current&&!dialog.current.open)dialog.current.showModal();},[room,preparing]);
 function release(){const old=session.current?.room.id;if(old)setRooms(values=>values.filter(value=>value.id!==old));generation.current++;starting.current=false;screenStop.current?.();screenStop.current=null;session.current?.release();session.current=null;setRoom(null);setLocal(null);setRemote(new Map());setPreparing(false);setSharing(false);setMuted(false);setCameraOff(false);}
 async function leave(everyone=false){const current=session.current?.room;release();if(current)try{if(everyone)await api.endCall(current.id);else await api.leaveCall(current.id);}catch(e){setError((e as Error).message);}}
 async function connect(scope:'DIRECT'|'CIRCLE',id:number,mode:'AUDIO'|'VIDEO',existing?:api.CallRoom){
  if(starting.current||session.current)return;starting.current=true;const token=++generation.current;setPreparing(true);setError('');let stream:MediaStream|null=null,current:api.CallRoom|undefined;
  try{
   if(!navigator.mediaDevices?.getUserMedia)throw new Error('Calling requires HTTPS and microphone access in this browser.');
   const ice=await fetchCallIceConfiguration();if(token!==generation.current)return;
   stream=await navigator.mediaDevices.getUserMedia({audio:true,video:mode==='VIDEO'?{width:{ideal:640},height:{ideal:360},frameRate:{ideal:15,max:24}}:false});
   if(token!==generation.current){stream.getTracks().forEach(track=>track.stop());return;}
   current=existing||await api.createCall(scope,id,mode);
   if(token!==generation.current){stream.getTracks().forEach(track=>track.stop());if(!existing)void api.leaveCall(current.id).catch(()=>{});return;}
   if(current.callType==='AUDIO')for(const track of stream.getVideoTracks()){track.stop();stream.removeTrack(track);}
   setRoom(current);setLocal(stream);setPreparing(false);
   const engine=new MeetingSession(current,stream,(value,streams)=>{if(token===generation.current){setRoom(value);setRemote(streams);}},message=>{if(token===generation.current)setError(message);},()=>{if(token===generation.current)release();},{iceServers:ice.iceServers});
   session.current=engine;await engine.start();
  }catch(e){stream?.getTracks().forEach(track=>track.stop());if(current)void api.leaveCall(current.id).catch(()=>{});if(token===generation.current){release();setError(e instanceof DOMException&&e.name==='NotAllowedError'?'Allow microphone/camera access to place a call.':(e as Error).message);}}
  finally{if(token===generation.current){starting.current=false;setPreparing(false);}}
 }
 async function share(){try{if(sharing){screenStop.current?.();screenStop.current=null;setSharing(false);return;}const stream=await navigator.mediaDevices.getDisplayMedia({video:true});if(!session.current){stream.getTracks().forEach(track=>track.stop());return;}const engine=session.current;const stop=await engine.shareScreen(stream);if(session.current!==engine){stop?.();return;}screenStop.current=stop||null;setSharing(true);stream.getVideoTracks()[0].onended=()=>{screenStop.current?.();screenStop.current=null;setSharing(false);};}catch(e){if((e as Error).name!=='NotAllowedError')setError((e as Error).message);}}
 const join=(value:api.CallRoom)=>void connect(value.scope,value.targetId,value.callType,value);
 return <Calls.Provider value={{begin:(scope,id,mode)=>void connect(scope,id,mode),rooms,join,busy:preparing||!!room}}>{children}
  {error&&!room&&!preparing&&<div className="messaging-call-notice" role="alert">{error}<button aria-label="Dismiss call error" onClick={()=>setError('')}>×</button></div>}
  {!room&&!preparing&&rooms.length>0&&<aside className="messaging-incoming" aria-label="Active calls">{rooms.slice(0,3).map(value=><div key={value.id}><strong>{value.name}</strong><span>{value.callType==='VIDEO'?'Video':'Voice'} call</span><button onClick={()=>join(value)}>{value.scope==='DIRECT'?'Answer':'Join call'}</button><button onClick={()=>{void api.leaveCall(value.id).then(()=>setRooms(values=>values.filter(item=>item.id!==value.id))).catch(e=>setError(e.message));}}>Decline</button></div>)}</aside>}
  {(room||preparing)&&createPortal(<dialog ref={dialog} className="messaging-call-dialog" aria-label={preparing?'Preparing call':`${room?.callType==='VIDEO'?'Video':'Voice'} call with ${room?.name}`} onCancel={event=>{event.preventDefault();void leave();}}>
   <header><h2>{room?.name||'Preparing call…'}</h2><span>{room?`${room.members.filter(member=>member.status==='JOINED').length}/${room.capacity} participants`:'Allow microphone access'}</span></header>
   {error&&<p role="alert">{error}</p>}
   <div className={`messaging-call-grid ${room?.callType==='AUDIO'?'audio-call':''}`}>{local&&<Media stream={local} muted name="You"/>}{Array.from(remote).map(([id,stream])=><Media key={id} stream={stream} name={room?.members.find(member=>member.userId===id)?.name||'Member'}/>)}{room&&!remote.size&&<p role="status">Waiting for others to join…</p>}</div>
   <footer>{local&&<><button aria-pressed={muted} onClick={()=>{local.getAudioTracks().forEach(track=>track.enabled=muted);setMuted(!muted);}}>{muted?'Unmute':'Mute'}</button>{room?.callType==='VIDEO'&&local.getVideoTracks().length>0&&<><button aria-pressed={cameraOff} onClick={()=>{local.getVideoTracks().forEach(track=>track.enabled=cameraOff);setCameraOff(!cameraOff);}}>{cameraOff?'Camera on':'Camera off'}</button>{typeof navigator.mediaDevices?.getDisplayMedia==='function'&&<button aria-pressed={sharing} onClick={()=>void share()}>{sharing?'Stop sharing':'Share screen'}</button>}</>}</>}
   <button className="call-hangup" onClick={()=>void leave()}>{preparing?'Cancel':'Leave call'}</button>{room?.creatorId===room?.currentUserId&&room?.scope==='CIRCLE'&&<button onClick={()=>void leave(true)}>End for everyone</button>}</footer>
  </dialog>,document.body)}
 </Calls.Provider>;
}
