'use client';
import {startPolling} from '../lib/polling';
import Link from 'next/link';
import InfoTip from '../components/InfoTip';
import ChatThread from '../messages/ChatThread';
import {FormEvent,useCallback,useEffect,useMemo,useRef,useState} from 'react';
import {useRouter} from 'next/navigation';
import {createMyCircle,fetchMyCircles,hasAuthSession,isUnauthorizedError,NetworkCircle} from '../lib/api';

export default function CirclesPage(){
  const router=useRouter();
  const [selected,setSelected]=useState<number|null>(null);
  const [circles,setCircles]=useState<NetworkCircle[]>([]),[query,setQuery]=useState('');
  const active=circles.find(c=>c.id===selected);
  const [loading,setLoading]=useState(true),[error,setError]=useState('');
  const [saving,setSaving]=useState(false),[createError,setCreateError]=useState('');
  const dialog=useRef<HTMLDialogElement>(null);
  const load=useCallback(async()=>{
    try{setCircles(await fetchMyCircles());setError('');}
    catch(caught){if(isUnauthorizedError(caught))router.replace('/auth');else setError((caught as Error).message);}
    finally{setLoading(false);}
  },[router]);
  useEffect(()=>{if(!hasAuthSession())router.replace('/auth');else return startPolling(load,30000);},[load,router]);
  useEffect(()=>{const listener=(event:Event)=>setQuery((event as CustomEvent<string>).detail);window.addEventListener('myaaptha:page-search',listener);return()=>window.removeEventListener('myaaptha:page-search',listener);},[]);
  const visible=useMemo(()=>{const term=query.trim().toLowerCase();return term?circles.filter(circle=>circle.name.toLowerCase().includes(term)||circle.description?.toLowerCase().includes(term)||circle.members.some(member=>member.person.displayName.toLowerCase().includes(term))):circles;},[circles,query]);
  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();if(saving)return;
    const form=event.currentTarget,values=new FormData(form),name=String(values.get('name')||'').trim();
    if(!name){setCreateError('Enter a circle name.');return;}
    setSaving(true);setCreateError('');
    try{await createMyCircle(name,String(values.get('description')||'').trim());form.reset();dialog.current?.close();await load();}
    catch(caught){if(isUnauthorizedError(caught))router.replace('/auth');else setCreateError((caught as Error).message);}
    finally{setSaving(false);}
  }
  return <main className={`messaging-workspace ${active?'has-chat':''}`}>
    <aside className="chat-inbox" aria-label="Your circles">
      <header className="chat-inbox-heading"><h1>Circles</h1><button aria-label="Create circle" title="Create circle" onClick={()=>{setCreateError('');dialog.current?.showModal();}}>+</button></header>
      {error&&<p role="alert">{error}</p>}
      <div className="chat-inbox-list">{visible.map(circle=><article className={`chat-inbox-row ${selected===circle.id?'selected':''}`} key={circle.id}>
        <button className="chat-open-row" aria-label={`Open ${circle.name}`} aria-current={selected===circle.id?'true':undefined} onClick={()=>setSelected(circle.id)}><span className="chat-avatar circle">{circle.name.charAt(0)}</span><span className="chat-row-copy"><strong>{circle.name}</strong><small>{circle.members.length} {circle.members.length===1?'member':'members'}</small></span></button>
        <div className="circle-inbox-tools"><InfoTip label={`Information about ${circle.name}`}><span className="circle-detail-lines"><strong>{circle.name}</strong><span>{circle.description}</span><span>Created by: {circle.ownerName}</span><span>Posting: {circle.currentUserCanPost?'Allowed':'Admins only'}</span><span>Your role: {circle.currentUserAdmin?'Admin':'Member'}</span></span></InfoTip>{circle.ownedByCurrentUser&&<Link href={`/contacts?circleId=${circle.id}`}>Private contacts</Link>}</div>
      </article>)}{!visible.length&&<p className="chat-thread-empty">{loading?'Loading circles...':'No circles in this view.'}</p>}</div>
    </aside>
    {active?<ChatThread key={active.id} chat={{type:'CIRCLE',id:active.id,name:active.name}} onBack={()=>setSelected(null)} onChanged={load} onOpenPerson={chat=>router.push(`/messages?person=${chat.id}`)}/>:<section className="chat-welcome"><span aria-hidden="true">◎</span><h2>Your circles</h2><p>{circles.length?'Choose a circle to view its conversation.':'Bring family, friends or colleagues together.'}</p>{!loading&&!circles.length&&<button className="btn btn-primary" onClick={()=>{setCreateError('');dialog.current?.showModal();}}>Create your first circle</button>}</section>}
    <dialog ref={dialog} className="workspace-dialog" aria-labelledby="create-circle-title" onCancel={event=>{if(saving)event.preventDefault();}}>
      <form onSubmit={submit}><header><h2 id="create-circle-title">Create circle</h2><button type="button" className="compact-icon-button" aria-label="Close create circle" disabled={saving} onClick={()=>dialog.current?.close()}>×</button></header>
        {createError&&<p role="alert" className="error-message">{createError}</p>}
        <label>Circle name<input name="name" required maxLength={120} autoFocus disabled={saving}/></label>
        <label>Description <span className="optional-label">(optional)</span><textarea name="description" maxLength={1000} rows={3} disabled={saving}/></label>
        <footer><button type="button" className="btn btn-secondary" disabled={saving} onClick={()=>dialog.current?.close()}>Cancel</button><button type="submit" className="btn btn-primary" disabled={saving}>{saving?'Creating…':'Create circle'}</button></footer>
      </form>
    </dialog>
  </main>;
}
