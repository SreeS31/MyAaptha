'use client';
import InfoTip from '../components/InfoTip';
import { FormEvent, Suspense, useEffect, useState } from 'react';
import { useRouter,useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { discoverPeople,DiscoveryResult,isUnauthorizedError } from '../lib/api';
import { DiscoveryResults } from '../components/DiscoveryResults';

function PeopleSearch(){
  const router=useRouter();const params=useSearchParams();const query=params.get('q')||'';
  const [input,setInput]=useState(query);const [result,setResult]=useState<DiscoveryResult>();const [loading,setLoading]=useState(false);const [error,setError]=useState('');
  useEffect(()=>{let active=true;setInput(query);setResult(undefined);setError('');if(query.trim().length<2){setLoading(false);return;}setLoading(true);discoverPeople(query).then(value=>{if(active)setResult(value);}).catch(e=>{if(isUnauthorizedError(e))router.replace('/auth');else if(active)setError(e.message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[query,router]);
  const search=(event:FormEvent)=>{event.preventDefault();if(input.trim().length>=2)router.push(`/discover?q=${encodeURIComponent(input.trim())}`);};
  return <main className="container" style={{maxWidth:1000,paddingBottom:100}}><header className="network-header"><div><p className="eyebrow">FIND YOUR COMMON GROUND</p><div className="inline-help-heading"><h1>People & connections</h1><InfoTip label="About People & connections">Find an existing person before adding someone new. See shared connections and interests they choose to share.</InfoTip></div></div><Link href="/settings" className="btn btn-secondary">Discovery settings</Link></header>
    <form className="card" role="search" onSubmit={search} style={{display:'flex',gap:12,flexWrap:'wrap'}}><input aria-label="Find people by name, location, interest or workplace" type="search" minLength={2} maxLength={160} required value={input} onChange={e=>setInput(e.target.value)} placeholder="Name, location, hobby or workplace" style={{flex:'1 1 250px',padding:14,border:'1px solid #cad8e2',borderRadius:12}}/><button className="btn btn-primary" disabled={loading}>Search people</button></form>
    {error&&<p role="alert" className="error-message">{error}</p>}{loading&&<p role="status">Finding people and shared connections…</p>}
    {result&&<section aria-label="People search results"><p>{result.rankingMode==='AI_ASSISTED'?'AI-assisted name ranking':result.rankingMode==='LOCAL_FALLBACK'?'Connection-based ordering · AI ranking is temporarily unavailable':'People search'} · {result.people.length} results</p><DiscoveryResults people={result.people}/><p>{result.explanation}</p>{result.limited&&<p>Showing a bounded selection of matches and shared links. Use a more specific search to narrow the results.</p>}</section>}
    {!query&&<section className="card" style={{marginTop:20}}><div className="inline-help-heading"><h2>A familiar face, a new connection</h2><InfoTip label="About A familiar face, a new connection">Try a person’s name, “gardening”, or a workplace. Private relationships and hidden interests stay private.</InfoTip></div><Link href="/settings">Choose what you share →</Link></section>}
  </main>;
}
export default function DiscoverPage(){return <Suspense fallback={<main className="container">Loading people search…</main>}><PeopleSearch/></Suspense>;}
