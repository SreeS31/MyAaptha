'use client';

import Link from 'next/link';
import {useEffect, useState} from 'react';
import {AiActionEvent, fetchAiActivity} from '../lib/api';

const capabilityLabel=(value:string)=>value.toLowerCase().split('_').map(word=>word[0].toUpperCase()+word.slice(1)).join(' ');

export default function AiActivityPage(){
  const [events,setEvents]=useState<AiActionEvent[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(true);
  useEffect(()=>{void fetchAiActivity().then(setEvents).catch(reason=>setError(reason instanceof Error?reason.message:'AI activity could not be loaded.')).finally(()=>setLoading(false));},[]);
  return <main className="container privacy-page">
    <header className="network-header"><div><p className="eyebrow">ACCOUNT · AI TRANSPARENCY</p><h1>AI activity</h1><p>See what MyAaptha AI processed, why it was used, and whether the operation succeeded. Private prompts and document contents are not stored in this ledger.</p></div><Link href="/dashboard" className="btn btn-secondary">Back to dashboard</Link></header>
    {error&&<p className="network-message" role="alert">{error}</p>}
    <section className="card privacy-list" aria-busy={loading}>
      <h2>Recent activity</h2>
      {loading&&<p>Loading AI activity...</p>}
      {!loading&&!events.length&&!error&&<p>No AI activity has been recorded for this account.</p>}
      {events.map(event=><article key={event.requestId}>
        <span><strong>{capabilityLabel(event.capability)}</strong><small>{event.purpose}</small><small>{new Date(event.createdAt).toLocaleString()} · {event.actionLevel} · {event.consentGranted?'Consent granted':'No sensitive consent required'}</small></span>
        <span className={`action-tag ${event.status==='FAILED'?'action-tag-danger':''}`}>{event.status.toLowerCase()}</span>
      </article>)}
    </section>
  </main>;
}
