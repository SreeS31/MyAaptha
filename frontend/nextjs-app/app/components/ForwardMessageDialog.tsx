'use client';
import {useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import {ChatTarget,fetchForwardTargets,forwardChatMessage} from '../lib/api';

export default function ForwardMessageDialog({sourceType,conversationId,messageId,onClose,onSent}:{sourceType:'DIRECT'|'CIRCLE';conversationId:number;messageId:number;onClose:()=>void;onSent:()=>void}){
  const dialog=useRef<HTMLDialogElement>(null);
  const [targets,setTargets]=useState<ChatTarget[]>([]),[selected,setSelected]=useState<ChatTarget[]>([]),[query,setQuery]=useState(''),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState('');
  useEffect(()=>{dialog.current?.showModal();let active=true;fetchForwardTargets().then(values=>{if(active)setTargets(values);}).catch(e=>{if(active)setError(e.message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[]);
  const key=(target:ChatTarget)=>`${target.type}:${target.id}`;
  async function send(){setBusy(true);setError('');try{await forwardChatMessage(sourceType,conversationId,messageId,selected.map(({type,id})=>({type,id})));onSent();}catch(e){setError((e as Error).message);setBusy(false);}}
  return createPortal(<dialog ref={dialog} className="chat-forward-dialog" aria-labelledby="forward-title" onCancel={event=>{event.preventDefault();if(!busy)onClose();}}>
    <header><h2 id="forward-title">Forward message</h2><button aria-label="Close forward picker" disabled={busy} onClick={onClose}>×</button></header>
    <input autoFocus type="search" aria-label="Find people or circles" placeholder="Find people or circles" value={query} onChange={event=>setQuery(event.target.value)}/>
    <p className="forward-selection-count" role="status">{selected.length} / 10 selected</p>
    <div className="forward-target-list">{loading?<p>Loading chats…</p>:targets.filter(target=>target.name.toLocaleLowerCase().includes(query.toLocaleLowerCase())).map(target=>{
      const checked=selected.some(value=>key(value)===key(target));
      return <label className="forward-target" key={key(target)}><input type="checkbox" aria-label={`${target.name} ${target.type==='CIRCLE'?'Circle':'Person'}`} checked={checked} disabled={busy||(!checked&&selected.length===10)} onChange={()=>setSelected(values=>checked?values.filter(value=>key(value)!==key(target)):[...values,target])}/><span aria-hidden="true" className={`forward-avatar ${target.type.toLowerCase()}`}>{target.type==='CIRCLE'?'◎':target.name.charAt(0).toUpperCase()}</span><span><strong>{target.name}</strong><small>{target.type==='CIRCLE'?'Circle':'Person'}</small></span></label>;
    })}{!loading&&!targets.length&&<p>No eligible people or circles yet.</p>}</div>
    {error&&<p role="alert">{error}</p>}
    <footer><button disabled={busy} onClick={onClose}>Cancel</button><button className="btn btn-primary" disabled={busy||!selected.length||selected.length>10} onClick={()=>void send()}>{busy?'Forwarding…':'Send forward'}</button></footer>
  </dialog>,document.body);
}
