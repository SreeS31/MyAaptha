"use client";
import InfoTip from '../components/InfoTip';
import Link from 'next/link';
import {useCallback,useEffect,useRef,useState} from 'react';
import {useRouter} from 'next/navigation';
import {AbuseReport,fetchModerationPage,fetchSessionProfile,hasAuthSession,isUnauthorizedError,updateModerationReport} from '../lib/api';

export default function ModerationPage(){
 const router=useRouter(),version=useRef(0);
 const [reports,setReports]=useState<AbuseReport[]>([]),[filter,setFilter]=useState('OPEN'),[message,setMessage]=useState(''),[busy,setBusy]=useState<number>(),[loading,setLoading]=useState(false),[cursor,setCursor]=useState<number|null>(null);
 const load=useCallback(async(before?:number,append=false)=>{
  const current=++version.current;setLoading(true);setMessage('');if(!append){setReports([]);setCursor(null);}
  try{
   if(!append){const profile=await fetchSessionProfile();if(current!==version.current)return;if(profile.role!=='ADMIN'){router.replace('/dashboard');return;}}
   const page=await fetchModerationPage(filter,before);if(current!==version.current)return;
   setReports(old=>append?[...old,...page.items.filter(item=>!old.some(r=>r.id===item.id))]:page.items);setCursor(page.nextCursor);
  }catch(error){if(current!==version.current)return;const status=(error as {status?:number}).status;if(status===401||status===403){setReports([]);setCursor(null);}if(isUnauthorizedError(error))router.replace('/auth');else setMessage((error as Error).message);}
  finally{if(current===version.current)setLoading(false);}
 },[filter,router]);
 useEffect(()=>{if(!hasAuthSession())router.replace('/auth');else void load();return()=>{version.current++;};},[load,router]);
 const update=async(report:AbuseReport,status:AbuseReport['status'])=>{
  const notes=window.prompt('Notes visible to the reporter',report.moderatorNotes||'');if(notes===null)return;
  setBusy(report.id);try{const updated=await updateModerationReport(report.id,status,notes);setReports(old=>old.map(r=>r.id===updated.id?updated:r).filter(r=>filter==='ALL'||r.status===filter));setMessage(`Report #${report.id} updated.`);}
  catch(error){if([401,403].includes((error as {status?:number}).status||0)){setReports([]);setCursor(null);}setMessage((error as Error).message);}finally{setBusy(undefined);}
 };
 return <main className="container moderation-page"><header className="network-header"><div><p className="eyebrow">TRUST &amp; SAFETY</p><div className="inline-help-heading"><h1>Moderation queue</h1><InfoTip label="About Moderation queue">Reports load newest first. Filters search the full queue. Refresh to include newer reports. Status changes do not remove content. Notes are visible to the reporter.</InfoTip></div></div><div><button disabled={loading||busy!==undefined} onClick={()=>void load()}>Refresh queue</button> <Link href="/dashboard" className="btn btn-secondary">Dashboard</Link></div></header>
 {message&&<p className="network-message" role="status">{message}</p>}
 <nav className="moderation-filters" aria-label="Report status">{['OPEN','REVIEWING','RESOLVED','DISMISSED','ALL'].map(value=><button key={value} disabled={busy!==undefined} aria-pressed={filter===value} className={filter===value?'active':''} onClick={()=>setFilter(value)}>{value.toLowerCase()}</button>)}</nav>
 <p>{reports.length} reports loaded{loading?' ? Loading...':''}</p>
 <section className="moderation-list">{reports.map(report=><article className="card" key={report.id}><header><span className={`moderation-status status-${report.status.toLowerCase()}`}>{report.status}</span><time>{new Date(report.createdAt).toLocaleString()}</time></header><h2>{report.reason.replaceAll('_',' ')}</h2><p>{report.details||'No additional details supplied.'}</p><dl><div><dt>Report</dt><dd>#{report.id}</dd></div><div><dt>Entity</dt><dd>{report.entityType||'Account'} {report.entityId?`#${report.entityId}`:''}</dd></div><div><dt>Reported user</dt><dd>{report.reportedUserId?`#${report.reportedUserId}`:'?'}</dd></div></dl>{report.moderatorNotes&&<blockquote>{report.moderatorNotes}</blockquote>}<footer><button disabled={loading||busy!==undefined} onClick={()=>void update(report,'REVIEWING')}>Reviewing</button><button disabled={loading||busy!==undefined} onClick={()=>void update(report,'RESOLVED')}>Resolve</button><button disabled={loading||busy!==undefined} onClick={()=>void update(report,'DISMISSED')}>Dismiss</button></footer></article>)}{!loading&&!reports.length&&<div className="card social-empty"><h2>No {filter.toLowerCase()} reports loaded</h2></div>}</section>
 {cursor!==null&&<button disabled={loading||busy!==undefined} onClick={()=>void load(cursor,true)}>Load more reports</button>}
 </main>;
}
