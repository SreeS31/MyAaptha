'use client';
import {useEffect,useRef,useState} from 'react';

export default function MessageDeleteMenu({canDeleteForAll,onDeleteForMe,onDeleteForAll}:{canDeleteForAll:boolean;onDeleteForMe:()=>Promise<unknown>;onDeleteForAll:()=>Promise<unknown>}) {
  const [open,setOpen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState('');
  const root=useRef<HTMLDivElement>(null),trigger=useRef<HTMLButtonElement>(null);
  useEffect(()=>{if(!open)return;const dismiss=(e:PointerEvent)=>{if(!root.current?.contains(e.target as Node))setOpen(false);};const escape=(e:KeyboardEvent)=>{if(e.key==='Escape'){setOpen(false);trigger.current?.focus();}};document.addEventListener('pointerdown',dismiss);document.addEventListener('keydown',escape);return()=>{document.removeEventListener('pointerdown',dismiss);document.removeEventListener('keydown',escape);};},[open]);
  async function remove(all:boolean){if(all&&!confirm('Delete this message for all participants?'))return;setBusy(true);setError('');try{await (all?onDeleteForAll():onDeleteForMe());setOpen(false);}catch(e){setError(e instanceof Error?e.message:'Could not delete message.');}finally{setBusy(false);}}
  return <div ref={root} className="message-delete-control"><button ref={trigger} type="button" className="message-action-danger" aria-expanded={open} disabled={busy} onClick={()=>setOpen(!open)}>Delete</button>{open&&<div className="message-delete-options" role="group" aria-label="Delete options"><button disabled={busy} onClick={()=>void remove(false)}>Delete for me</button>{canDeleteForAll&&<button className="message-action-danger" disabled={busy} onClick={()=>void remove(true)}>Delete for all</button>}</div>}{error&&<p role="alert">{error}</p>}</div>;
}
