'use client';
import {useEffect,useRef,useState} from 'react';
import {SocialPost,fetchSocialMedia} from '../lib/api';
import './post-options.css';

const quick=['👍','❤️','😂','😮','😢','🙏'];
const extra=['😀','😁','🥰','😍','😘','🤗','🤩','🥳','😎','🤔','😅','😆','🤣','😭','😡','😔','😴','💔','💯','🎉','👏','🙌','💪','👌','🤝','🌹','🌟','🔥','✅','🫶'];
type Props={post:SocialPost;busy?:boolean;onReact:(emoji:string|null)=>Promise<void>;onPin:()=>Promise<void>;onStar:()=>Promise<void>;onReply:()=>void;onForward:()=>void;onEdit:()=>void;onDelete:()=>Promise<void>;onReport:()=>void;onAsk:()=>void;onNotice:(text:string)=>void};

export default function PostOptions({post,busy,onReact,onPin,onStar,onReply,onForward,onEdit,onDelete,onReport,onAsk,onNotice}:Props){
 const root=useRef<HTMLDetailsElement>(null),info=useRef<HTMLDialogElement>(null);
 const [placement,setPlacement]=useState({up:false,height:560});
 const [open,setOpen]=useState(false),[more,setMore]=useState(false),[emoji,setEmoji]=useState('');
 const close=()=>{if(root.current)root.current.open=false;setMore(false);};
 useEffect(()=>{if(!open)return;const outside=(event:PointerEvent)=>{if(!root.current?.contains(event.target as Node))close();};document.addEventListener('pointerdown',outside);return()=>document.removeEventListener('pointerdown',outside);},[open]);
 const run=async(action:()=>void|Promise<void>)=>{close();try{await action();}catch(error){onNotice((error as Error).message||'The action could not be completed.');}};
 const copy=async()=>{const value=post.caption||new URL(`/online-feed?postId=${post.id}`,location.origin).href;
  if(navigator.clipboard?.writeText)await navigator.clipboard.writeText(value);
  else{const field=document.createElement('textarea');field.value=value;field.style.position='fixed';field.style.opacity='0';document.body.appendChild(field);field.select();try{if(!document.execCommand('copy'))throw Error('Copy is unavailable in this browser.');}finally{field.remove();}}
  onNotice('Copied to clipboard.');};
 const download=async()=>{const blob=post.mediaUrl?await fetchSocialMedia(post.mediaUrl):new Blob([post.caption],{type:'text/plain;charset=utf-8'});const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download=post.mediaName||`myaaptha-post-${post.id}.txt`;link.click();window.setTimeout(()=>URL.revokeObjectURL(url),60000);};
 const react=(value:string)=>run(()=>onReact(post.myReaction===value?null:value));
 return <>
  <details ref={root} className="post-options" onToggle={event=>{const value=event.currentTarget.open;if(value){const box=event.currentTarget.getBoundingClientRect();const ceiling=(document.querySelector('.workspace-topbar')?.getBoundingClientRect().bottom||60)+8;const floor=innerHeight-(matchMedia('(pointer:coarse)').matches?76:12);const below=floor-box.bottom,above=box.top-ceiling-8;const up=below<420&&above>below;setPlacement({up,height:Math.max(80,Math.min(620,up?above:below))});}setOpen(value);}} onKeyDown={event=>{
   if(event.key==='Escape'){event.preventDefault();close();root.current?.querySelector('summary')?.focus();return;}
   if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){event.preventDefault();if(root.current)root.current.open=true;requestAnimationFrame(()=>{const buttons=Array.from(root.current?.querySelectorAll<HTMLButtonElement>('[role=menuitem]:not(:disabled)')||[]);const i=buttons.indexOf(document.activeElement as HTMLButtonElement);buttons[event.key==='Home'?0:event.key==='End'?buttons.length-1:event.key==='ArrowUp'?(i-1+buttons.length)%buttons.length:(i+1)%buttons.length]?.focus();});}
  }}>
   <summary aria-label="Post options" title="Post options" aria-haspopup="menu">⋯</summary>
   {open&&<div className="post-options-popup" style={{maxHeight:placement.height,...(placement.up?{top:'auto',bottom:36}:{})}}>
    <div className="post-quick-reactions" role="group" aria-label="Quick reactions">{quick.map(value=><button type="button" key={value} aria-label={`React ${value}`} aria-pressed={post.myReaction===value} disabled={busy} onClick={()=>void react(value)}>{value}</button>)}<button type="button" aria-label="More reactions" aria-expanded={more} onClick={()=>setMore(value=>!value)}>+</button></div>
    {more&&<div className="post-emoji-picker" role="group" aria-label="More emoji reactions">{extra.map(value=><button type="button" key={value} aria-label={`React ${value}`} disabled={busy} onClick={()=>void react(value)}>{value}</button>)}<form onSubmit={event=>{event.preventDefault();if(emoji.trim())void react(emoji.trim());}}><input aria-label="Custom emoji reaction" maxLength={32} placeholder="Choose an emoji…" value={emoji} onChange={event=>setEmoji(event.target.value)}/><button type="submit" disabled={busy||!emoji.trim()}>React</button></form></div>}
    <div className="post-menu-list" role="menu" aria-label="Post actions">
     <button type="button" role="menuitem" onClick={()=>{close();info.current?.showModal();}}><span aria-hidden="true">ⓘ</span>Post info</button>
     <button type="button" role="menuitem" onClick={()=>void run(onReply)}><span aria-hidden="true">↩</span>Reply</button>
     <button type="button" role="menuitem" onClick={()=>void run(copy)}><span aria-hidden="true">▣</span>Copy</button>
     <button type="button" role="menuitem" onClick={()=>setMore(value=>!value)}><span aria-hidden="true">☺</span>React</button>
     <button type="button" role="menuitem" onClick={()=>void run(download)}><span aria-hidden="true">↓</span>Download</button>
     <button type="button" role="menuitem" onClick={()=>void run(onForward)}><span aria-hidden="true">↪</span>Forward</button>
     <button type="button" role="menuitem" disabled={busy} onClick={()=>void run(onPin)}><span aria-hidden="true">⌖</span>{post.pinned?'Unpin for me':'Pin for me'}</button>
     <button type="button" role="menuitem" onClick={()=>void run(onAsk)}><span aria-hidden="true">✧</span>Ask MyAaptha</button>
     <button type="button" role="menuitem" disabled={busy} onClick={()=>void run(onStar)}><span aria-hidden="true">☆</span>{post.savedByMe?'Unstar':'Star'}</button>
     {post.mine?<><button type="button" role="menuitem" onClick={()=>void run(onEdit)}><span aria-hidden="true">✎</span>Edit</button><button type="button" role="menuitem" className="post-menu-danger" disabled={busy} onClick={()=>void run(onDelete)}><span aria-hidden="true">⌫</span>Delete</button></>:<button type="button" role="menuitem" onClick={()=>void run(onReport)}><span aria-hidden="true">⚑</span>Report</button>}
    </div>
   </div>}
  </details>
  <dialog ref={info} className="post-info-dialog" aria-label="Post info" onClose={()=>root.current?.querySelector('summary')?.focus()}><header><h2>Post info</h2><button type="button" onClick={()=>info.current?.close()}>Close</button></header><dl><dt>Author</dt><dd>{post.authorName}</dd><dt>Created</dt><dd>{new Date(post.createdAt).toLocaleString()}</dd><dt>Updated</dt><dd>{new Date(post.updatedAt).toLocaleString()}</dd><dt>Audience</dt><dd>{post.audience==='CIRCLE'?'Selected circle':post.audience.toLowerCase()}</dd><dt>Reactions</dt><dd>{post.likeCount}</dd><dt>Reaction breakdown</dt><dd>{Object.entries(post.reactions||{}).map(([emoji,count])=>`${emoji} ${count}`).join(' ? ')||'No reactions'}</dd><dt>Comments</dt><dd>{post.commentCount}</dd><dt>Your pin</dt><dd>{post.pinned?'Pinned for you':'Not pinned'}</dd><dt>Your star</dt><dd>{post.savedByMe?'Starred (saved posts)':'Not starred'}</dd>{post.mediaName&&<><dt>Attachment</dt><dd>{post.mediaName}{post.mediaSize?` (${(post.mediaSize/1048576).toFixed(2)} MB)`:''}</dd></>}</dl><p>Pinning and starring apply only to your account.</p></dialog>
 </>;
}
