'use client';

import Link from 'next/link';
import {useEffect, useState} from 'react';
import {AiActionEvent, AiPreference, fetchAiActivity, fetchAiPreferences, updateAiPreferences} from '../lib/api';

const capabilityLabel=(value:string)=>value.toLowerCase().split('_').map(word=>word[0].toUpperCase()+word.slice(1)).join(' ');
const defaults:AiPreference={userId:0,aiEnabled:true,allowSensitiveData:false,allowPersonalization:false,activityRetentionDays:90};

export default function AiActivityPage(){
  const [events,setEvents]=useState<AiActionEvent[]>([]);
  const [preferences,setPreferences]=useState<AiPreference>(defaults);
  const [error,setError]=useState('');
  const [message,setMessage]=useState('');
  const [loading,setLoading]=useState(true);
  const [saving,setSaving]=useState(false);
  useEffect(()=>{void Promise.all([fetchAiActivity(),fetchAiPreferences()]).then(([activity,settings])=>{setEvents(activity);setPreferences(settings);}).catch(reason=>setError(reason instanceof Error?reason.message:'AI controls could not be loaded.')).finally(()=>setLoading(false));},[]);
  const change=(patch:Partial<AiPreference>)=>setPreferences(value=>({...value,...patch}));
  const save=async()=>{if(preferences.activityRetentionDays<0||preferences.activityRetentionDays>365){setError('Choose an activity retention period from 0 to 365 days.');return;}setSaving(true);setError('');setMessage('');try{const updated=await updateAiPreferences({aiEnabled:preferences.aiEnabled,allowSensitiveData:preferences.aiEnabled&&preferences.allowSensitiveData,allowPersonalization:preferences.aiEnabled&&preferences.allowPersonalization,activityRetentionDays:preferences.activityRetentionDays});setPreferences(updated);if(updated.activityRetentionDays===0)setEvents([]);setMessage('AI controls saved. Server enforcement is active.');}catch(reason){setError(reason instanceof Error?reason.message:'AI controls could not be saved.');}finally{setSaving(false);}};
  return <main className="container privacy-page">
    <header className="network-header"><div><p className="eyebrow">ACCOUNT · AI TRANSPARENCY</p><h1>AI control center</h1><p>Control AI access and inspect what MyAaptha processed. Private prompts and document contents are not stored in the activity ledger.</p></div><Link href="/dashboard" className="btn btn-secondary">Back to dashboard</Link></header>
    {error&&<p className="network-message" role="alert">{error}</p>}{message&&<p className="network-message" role="status">{message}</p>}
    <section className="card privacy-search" aria-busy={loading}><h2>Permissions</h2>
      <label className="contact-consent"><input type="checkbox" checked={preferences.aiEnabled} disabled={loading||saving} onChange={event=>change({aiEnabled:event.target.checked,allowSensitiveData:event.target.checked&&preferences.allowSensitiveData,allowPersonalization:event.target.checked&&preferences.allowPersonalization})}/><span><strong>Enable AI assistance</strong><small>Master switch for all AI processing. Turning it off blocks AI requests at the API.</small></span></label>
      <label className="contact-consent"><input type="checkbox" checked={preferences.allowSensitiveData} disabled={!preferences.aiEnabled||loading||saving} onChange={event=>change({allowSensitiveData:event.target.checked})}/><span><strong>Allow sensitive-data assistance</strong><small>Required before AI can process contacts, relationship graphs, profiles, health, or wealth data. Each operation still requires its own consent.</small></span></label>
      <label className="contact-consent"><input type="checkbox" checked={preferences.allowPersonalization} disabled={!preferences.aiEnabled||loading||saving} onChange={event=>change({allowPersonalization:event.target.checked})}/><span><strong>Allow personalization</strong><small>Lets MyAaptha adapt suggestions to your saved preferences. This does not permit model training.</small></span></label>
      <label><span>AI activity retention</span><select value={preferences.activityRetentionDays} disabled={loading||saving} onChange={event=>change({activityRetentionDays:Number(event.target.value)})}><option value={0}>Do not retain activity</option><option value={30}>30 days</option><option value={90}>90 days</option><option value={180}>180 days</option><option value={365}>365 days</option></select></label>
      <button type="button" className="btn btn-primary" disabled={loading||saving} onClick={()=>void save()}>{saving?'Saving...':'Save AI controls'}</button>
    </section>
    <section className="card privacy-list" aria-busy={loading}><h2>Recent activity</h2>{loading&&<p>Loading AI activity...</p>}{!loading&&!events.length&&!error&&<p>No AI activity has been recorded for this account.</p>}{events.map(event=><article key={event.requestId}><span><strong>{capabilityLabel(event.capability)}</strong><small>{event.purpose}</small><small>{new Date(event.createdAt).toLocaleString()} · {event.actionLevel} · {event.consentGranted?'Consent granted':'No sensitive consent required'}</small></span><span className={`action-tag ${event.status==='FAILED'?'action-tag-danger':''}`}>{event.status.toLowerCase()}</span></article>)}</section>
  </main>;
}
