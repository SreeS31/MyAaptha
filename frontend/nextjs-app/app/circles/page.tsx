'use client';
import {startPolling} from '../lib/polling';
import PageHeading from '../components/PageHeading';
import CircleBranch from './CircleBranch';
import styles from './page.module.css';
import {FormEvent,useCallback,useEffect,useMemo,useRef,useState} from 'react';
import {useRouter} from 'next/navigation';
import {AddressCircle,createMyCircle,fetchAddressCircles,fetchMyCircles,hasAuthSession,isUnauthorizedError,NetworkCircle} from '../lib/api';

export default function CirclesPage(){
  const router=useRouter();
  const [expanded,setExpanded]=useState<Set<number>>(new Set());
  const [privateCircles,setPrivateCircles]=useState<AddressCircle[]>([]);
  const [circles,setCircles]=useState<NetworkCircle[]>([]),[query,setQuery]=useState('');
  const [loading,setLoading]=useState(true),[error,setError]=useState('');
  const [saving,setSaving]=useState(false),[createError,setCreateError]=useState('');
  const dialog=useRef<HTMLDialogElement>(null);
  const load=useCallback(async()=>{
    try{const [network,privateLists]=await Promise.all([fetchMyCircles(),fetchAddressCircles()]);setCircles(network);setPrivateCircles(privateLists);setError('');}
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
  return <main className={styles.page}>
    <PageHeading title="My circles" actions={<button className="btn btn-primary" aria-label="Create circle" onClick={()=>{setCreateError('');dialog.current?.showModal();}}>+ Create circle</button>}/>
    <div className={styles.toolbar}><input type="search" aria-label="Search circles" placeholder="Search circles" value={query} onChange={event=>setQuery(event.target.value)}/><button type="button" className="btn btn-secondary" onClick={()=>setExpanded(new Set())}>Collapse all</button></div>
    {error&&<p role="alert">{error}</p>}
    <section aria-label="Circle tree" className={styles.tree}>
      <div className={styles.root}><span aria-hidden="true">{'\u25ce'}</span><strong>You</strong><small>{circles.length} {circles.length===1?'circle':'circles'}</small></div>
      <ul className={styles.branches}>{visible.map(circle=><li key={circle.id}><CircleBranch circle={circle} privateCount={privateCircles.find(item=>item.id===circle.id)?.privateContactCount||0} expanded={expanded.has(circle.id)} onToggle={()=>setExpanded(current=>{const next=new Set(current);if(next.has(circle.id))next.delete(circle.id);else next.add(circle.id);return next;})}/></li>)}</ul>
      {!visible.length&&<p className={styles.empty}>{loading?'Loading circles...':'No circles in this view.'}</p>}
    </section>
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
