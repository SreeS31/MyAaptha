'use client';

import Link from 'next/link';
import InfoTip from './InfoTip';
import {startPolling} from '../lib/polling';
import { useEffect, useMemo, useState, useRef } from 'react';
import { deleteTimelineEvent, fetchTimelineEvents, saveTimelineEvent, SavedTimelineEvent, fetchMyRelationships, fetchUserProfile, NetworkRelationship, UserProfile } from '../lib/api';

type TimelineEvent = { eventKey:string; date: string; label: string; title: string; detail: string; kind: string; icon:string; sourceBacked?:boolean };

function MilestoneIcon({kind}:{kind:string}){
  const common={fill:'none',stroke:'currentColor',strokeWidth:1.8,strokeLinecap:'round' as const,strokeLinejoin:'round' as const};
  if(kind==='Education')return <svg viewBox="0 0 32 32" aria-hidden="true"><path {...common} d="M4 8.5 16 4l12 4.5L16 13 4 8.5Zm4 3.2V20c5 3.2 11 3.2 16 0v-8.3M28 9v9"/></svg>;
  if(kind==='Marriage')return <svg viewBox="0 0 32 32" aria-hidden="true"><circle {...common} cx="12" cy="17" r="7"/><circle {...common} cx="20" cy="17" r="7"/><path {...common} d="m13 7 3-3 3 3-3 3-3-3Z"/></svg>;
  if(kind==='Family')return <svg viewBox="0 0 32 32" aria-hidden="true"><circle {...common} cx="16" cy="12" r="6"/><path {...common} d="M10 12c2 1.8 4 2.7 6 2.7s4-.9 6-2.7M8 27c.8-6 3.5-9 8-9s7.2 3 8 9M13 10h.1M19 10h.1"/></svg>;
  if(kind==='Employment')return <svg viewBox="0 0 32 32" aria-hidden="true"><rect {...common} x="4" y="9" width="24" height="17" rx="3"/><path {...common} d="M11 9V6h10v3M4 16c7 4 17 4 24 0M14 16h4"/></svg>;
  if(kind==='Remembrance')return <svg viewBox="0 0 32 32" aria-hidden="true"><path {...common} d="M16 27S6 21 6 13a6 6 0 0 1 10-4 6 6 0 0 1 10 4c0 8-10 14-10 14Z"/><path {...common} d="M16 11v8m-4-4h8"/></svg>;
  return <svg viewBox="0 0 32 32" aria-hidden="true"><path {...common} d="M16 27S6 21 6 13a6 6 0 0 1 10-4 6 6 0 0 1 10 4c0 8-10 14-10 14Z"/><path {...common} d="M13 14c2 2 4 2 6 0M13 11h.1M19 11h.1"/></svg>;
}

function displayDate(value: string) {
  if (/^\d{4}$/.test(value)) return value;
  const parsed = new Date(`${value}${value.length === 7 ? '-01' : ''}T00:00:00`);
  return Number.isNaN(parsed.valueOf()) ? value : new Intl.DateTimeFormat(undefined, { day: value.length > 7 ? 'numeric' : undefined, month: 'short', year: 'numeric' }).format(parsed);
}

export default function LifeTimeline({ compact = false }: { compact?: boolean }) {
  const [saved,setSaved]=useState<SavedTimelineEvent[]>([]);
  const [dense,setDense]=useState(false);
  const [editor,setEditor]=useState<SavedTimelineEvent|null>(null);
  const dialog=useRef<HTMLDialogElement>(null);
  useEffect(()=>{if(editor&&!dialog.current?.open)dialog.current?.showModal();},[editor]);
  const [saving,setSaving]=useState(false);
  const mutationVersion=useRef(0);
  const mutating=useRef(false);
  const [saveError,setSaveError]=useState('');
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [error, setError] = useState('');
  const [relationships,setRelationships]=useState<NetworkRelationship[]>([]);
  const [parentsOpen, setParentsOpen] = useState(false);
  useEffect(() => { let active=true;const load=()=>{if(mutating.current)return Promise.resolve();const version=mutationVersion.current;return Promise.all([fetchUserProfile(),fetchMyRelationships(),fetchTimelineEvents()]).then(([loadedProfile,loadedRelationships,loadedEvents])=>{if(active&&version===mutationVersion.current&&!mutating.current){setProfile(loadedProfile);setRelationships(loadedRelationships);setSaved(loadedEvents);setError('');}}).catch(()=>{if(active&&version===mutationVersion.current&&!mutating.current)setError('Timeline details could not be loaded.');});};const stop=startPolling(load,120000);const focus=()=>void load();window.addEventListener('focus',focus);return()=>{active=false;stop();window.removeEventListener('focus',focus);}; }, []);
  const events = useMemo(() => {
    if (!profile) return [];
    const values: TimelineEvent[] = [];
    const birthDate = String(profile.dateOfBirth || '');
    if (birthDate) values.push({ eventKey:'profile-birth', date: birthDate, label: displayDate(birthDate), kind: 'Birth', icon:'✦', title: 'Born', detail: String(profile.location || '') });
    const graduationYear = String(profile.graduationYear || '');
    if (graduationYear) values.push({ eventKey:'profile-education', date: `${graduationYear}-12-31`, label: graduationYear, kind: 'Education', icon:'◆', title: String(profile.highestQualification || 'Graduated'), detail: [profile.institution, profile.fieldOfStudy].filter(Boolean).join(' · ') });
    relationships.forEach(relationship=>{
      const type=relationship.type.toLowerCase();
      if (relationship.milestoneDate&&['wife','husband'].includes(type)) values.push({eventKey:`relation-${relationship.id}-marriage`,date:relationship.milestoneDate,label:displayDate(relationship.milestoneDate),kind:'Marriage',icon:'♥',title:`Married ${relationship.person.displayName}`,detail:`Marriage with ${relationship.person.displayName}`});
      if (relationship.dateOfBirth&&['son','daughter','grandson','granddaughter'].includes(type)) values.push({eventKey:`relation-${relationship.id}-birth`,date:relationship.dateOfBirth,label:displayDate(relationship.dateOfBirth),kind:'Family',icon:'★',title:`${relationship.person.displayName} was born`,detail:`My ${relationship.type.toLowerCase()}`});
      if (relationship.dateOfDeath) values.push({eventKey:`relation-${relationship.id}-death`,date:relationship.dateOfDeath,label:displayDate(relationship.dateOfDeath),kind:'Remembrance',icon:'✧',title:`Remembering ${relationship.person.displayName}`,detail:`My ${relationship.type.toLowerCase()}`});
    });
    const combined=new Map(values.map(event=>[event.eventKey,event]));
    saved.forEach(event=>combined.set(event.eventKey,{...event,label:displayDate(event.date),icon:'',sourceBacked:values.some(value=>value.eventKey===event.eventKey)}));
    return Array.from(combined.values()).sort((a,b)=>b.date.localeCompare(a.date)||a.eventKey.localeCompare(b.eventKey));
  }, [profile,relationships,saved]);
  if (error) return <p className="network-message error-message" role="alert">{error}</p>;
  if (!profile) return <p className="timeline-empty">Loading timeline…</p>;
  return <section className={`life-timeline-card card ${compact ? 'timeline-dashboard-preview' : ''} ${dense&&!compact?'timeline-dense':''}`} aria-label="Life timeline">
    <div className="life-timeline-heading"><div><p className="eyebrow">LIFE JOURNEY</p><div className="inline-help-heading"><h2>{compact ? 'My timeline' : 'Major milestones'}</h2><InfoTip label="About timeline milestones">Latest events appear first. Use Add event or Edit event to save a timeline milestone. Wave view alternates cards; Compact view reduces spacing.</InfoTip></div></div>{compact&&<Link className="btn btn-secondary" href="/timeline">View timeline</Link>}</div>
    {!compact&&<div className="timeline-toolbar"><div role="group" aria-label="Timeline view"><button type="button" className="btn btn-secondary" aria-pressed={!dense} onClick={()=>setDense(false)}>Wave view</button><button type="button" className="btn btn-secondary" aria-pressed={dense} onClick={()=>setDense(true)}>Compact view</button></div><button type="button" className="btn btn-primary" onClick={()=>{setSaveError('');setEditor({eventKey:`custom-${crypto.randomUUID()}`,date:new Date().toLocaleDateString('en-CA'),kind:'Other',title:'',detail:''});}}>Add event</button></div>}
    {editor&&<dialog ref={dialog} className="card timeline-editor" aria-label={events.some(event=>event.eventKey===editor.eventKey)?'Edit event':'Add event'} onCancel={e=>{e.preventDefault();if(!saving)setEditor(null);}}><h2 id="timeline-editor-title">{events.some(event=>event.eventKey===editor.eventKey)?'Edit event':'Add event'}</h2><p>Saved to your timeline. Profile and relationship details remain separate.</p><form onSubmit={async e=>{e.preventDefault();setSaving(true);mutating.current=true;mutationVersion.current++;setSaveError('');try{const updated=await saveTimelineEvent(editor);setSaved(items=>[...items.filter(item=>item.eventKey!==updated.eventKey),updated]);setEditor(null);}catch(err){setSaveError((err as Error).message);}finally{setSaving(false);mutating.current=false;}}}><label>Event type<select value={editor.kind} disabled={saving} onChange={e=>setEditor({...editor,kind:e.target.value})}>{['Birth','Family','Remembrance','Education','Marriage','Employment','Other'].map(kind=><option key={kind}>{kind}</option>)}</select></label><label>Date<input required type="date" value={editor.date} disabled={saving} onChange={e=>setEditor({...editor,date:e.target.value})}/></label><label>Title<input required maxLength={200} value={editor.title} disabled={saving} onChange={e=>setEditor({...editor,title:e.target.value})}/></label><label>Details<textarea rows={3} maxLength={2000} value={editor.detail} disabled={saving} onChange={e=>setEditor({...editor,detail:e.target.value})}/></label>{saveError&&<p role="alert" className="error-message">{saveError}</p>}<footer>{saved.some(event=>event.eventKey===editor.eventKey)&&<button type="button" className="btn btn-secondary" disabled={saving} onClick={async()=>{
      const sourceBacked=events.find(event=>event.eventKey===editor.eventKey)?.sourceBacked;
      if(!window.confirm(sourceBacked?'Reset this event to the original profile or relationship milestone?':'Delete this saved timeline event?'))return;
      setSaving(true);mutating.current=true;mutationVersion.current++;setSaveError('');
      try{await deleteTimelineEvent(editor.eventKey);setSaved(items=>items.filter(item=>item.eventKey!==editor.eventKey));setEditor(null);}
      catch(err){setSaveError((err as Error).message);}
      finally{setSaving(false);mutating.current=false;}
    }}>{events.find(event=>event.eventKey===editor.eventKey)?.sourceBacked?'Reset to source':'Delete event'}</button>}<button type="button" className="btn btn-secondary" disabled={saving} onClick={()=>setEditor(null)}>Cancel</button><button className="btn btn-primary" disabled={saving}>{saving?'Saving…':'Save event'}</button></footer></form></dialog>}
    {events.length ? <div className="life-timeline-track">{events.map((event,index)=><article className={`life-timeline-event timeline-node-${index%2?'below':'above'} timeline-kind-${event.kind.toLowerCase()}`} style={{'--timeline-index':index} as React.CSSProperties} key={event.eventKey}>{!compact&&<svg className="timeline-wave-line" viewBox="0 0 80 100" preserveAspectRatio="none" aria-hidden="true"><path d={index%2===0?'M40 0 C0 20 0 80 40 100':'M40 0 C80 20 80 80 40 100'}/></svg>}<div className="timeline-event-card"><time dateTime={event.date}>{event.label}</time><small className="timeline-event-tag">{event.kind}</small><h3>{event.title}</h3>{event.detail&&<p>{event.detail}</p>}{!compact&&<button type="button" className="timeline-edit-button" aria-label={`Edit ${event.title}`} onClick={()=>{setSaveError('');setEditor({eventKey:event.eventKey,date:event.date,kind:event.kind,title:event.title,detail:event.detail});}}>Edit event</button>}{event.kind==='Birth'&&!compact&&<><button type="button" className="timeline-parent-button" aria-expanded={parentsOpen} onClick={()=>setParentsOpen(value=>!value)}>{parentsOpen?'Hide parents details':'Show parents details'}</button>{parentsOpen&&<div className="timeline-parent-details">{relationships.filter(item=>['mother','father'].includes(item.type.toLowerCase())).map(parent=><p key={parent.id}><strong>{parent.type}:</strong> {parent.person.displayName}</p>)}{!relationships.some(item=>['mother','father'].includes(item.type.toLowerCase()))&&<p>No parents added yet. Add them from the dashboard.</p>}</div>}</>}</div><div className="timeline-route-point"><div className="timeline-route-marker" aria-label={`${event.kind} milestone`}><MilestoneIcon kind={event.kind}/></div><strong className="timeline-route-year">{event.date.slice(0,4)}</strong></div>{index<events.length-1&&<svg className="timeline-curve" viewBox="0 0 250 100" preserveAspectRatio="none" aria-hidden="true"><path d={index%2===0?'M 0 0 C 105 0 145 100 250 100':'M 0 100 C 105 100 145 0 250 0'}/></svg>}</article>)}</div>:<div className="timeline-empty"><strong>No dated milestones yet.</strong><p>Add dates in <Link href="/profile">My profile</Link> or while adding relationships.</p></div>}
  </section>;
}
