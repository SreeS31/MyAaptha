'use client';
import {useEffect,useRef,useState} from 'react';

export default function VoiceRecorder({onReady,disabled}:{onReady:(file:File)=>void;disabled:boolean}){
 const [recording,setRecording]=useState(false),[pending,setPending]=useState(false),[seconds,setSeconds]=useState(0),[error,setError]=useState('');
 const recorder=useRef<MediaRecorder|null>(null),stream=useRef<MediaStream|null>(null),alive=useRef(true),discard=useRef(false),version=useRef(0),pendingRef=useRef(false);
 useEffect(()=>{if(disabled){version.current++;discard.current=true;if(recorder.current?.state==='recording')recorder.current.stop();stream.current?.getTracks().forEach(track=>track.stop());}},[disabled]);
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;version.current++;discard.current=true;if(recorder.current?.state==='recording')recorder.current.stop();stream.current?.getTracks().forEach(track=>track.stop());};},[]);
 useEffect(()=>{if(!recording)return;const timer=setInterval(()=>setSeconds(value=>{if(value>=299){recorder.current?.stop();return 300;}return value+1;}),1000);return()=>clearInterval(timer);},[recording]);
 async function begin(){
  if(pendingRef.current)return;pendingRef.current=true;const token=++version.current;setPending(true);setError('');discard.current=false;
  try{if(!navigator.mediaDevices?.getUserMedia||typeof MediaRecorder==='undefined')throw new Error('Voice recording is unavailable in this browser.');
   const media=await navigator.mediaDevices.getUserMedia({audio:true});if(!alive.current||token!==version.current){media.getTracks().forEach(track=>track.stop());return;}stream.current=media;
   const mime=['audio/webm;codecs=opus','audio/ogg;codecs=opus','audio/mp4'].find(type=>MediaRecorder.isTypeSupported(type));const value=new MediaRecorder(media,mime?{mimeType:mime}:undefined);recorder.current=value;const chunks:BlobPart[]=[];let bytes=0;
   value.ondataavailable=event=>{if(event.data.size){chunks.push(event.data);bytes+=event.data.size;if(bytes>=24*1024*1024&&value.state==='recording')value.stop();}};
   value.onstop=()=>{media.getTracks().forEach(track=>track.stop());stream.current=null;if(alive.current){setRecording(false);if(!discard.current&&chunks.length){const type=value.mimeType.split(';')[0]||'audio/webm',ext=type.includes('mp4')?'m4a':type.includes('ogg')?'ogg':'webm';onReady(new File(chunks,`voice-note-${Date.now()}.${ext}`,{type}));}}};
   value.start(1000);setRecording(true);setSeconds(0);
  }catch(e){if(alive.current)setError((e as Error).name==='NotAllowedError'?'Allow microphone access to record a voice note.':(e as Error).message);}
  finally{pendingRef.current=false;if(alive.current)setPending(false);}
 }
 return <div className="chat-voice-recorder">{recording?<><span role="status">Recording {Math.floor(seconds/60)}:{String(seconds%60).padStart(2,'0')}</span><button aria-label="Stop voice recording" onClick={()=>recorder.current?.stop()}>Stop</button><button aria-label="Discard voice recording" onClick={()=>{discard.current=true;recorder.current?.stop();}}>Cancel</button></>:<button disabled={disabled||pending} aria-label="Record voice note" onClick={()=>void begin()}>{pending?'…':<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/></svg>}</button>}{error&&<span role="alert">{error}</span>}</div>;
}
