'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { addMyRelationship, DiscoveryMatch } from '../lib/api';
import styles from './discovery.module.css';

export function DiscoveryResults({people}:{people:DiscoveryMatch[]}) {
  const [filter,setFilter]=useState('all');
  const visible=people.filter(m=>filter==='all'||filter==='new'&&!m.alreadyConnected||filter==='connected'&&m.alreadyConnected||filter==='shared'&&(m.mutualConnections.length>0||m.sharedInterests.length>0||!!m.sharedEmployer));
  return <div><div className={styles.filters} role="group" aria-label="People filters">{[['all','Everyone'],['new','New connections'],['connected','In my network'],['shared','Common ground']].map(([key,label])=><button type="button" key={key} aria-pressed={filter===key} onClick={()=>setFilter(key)}>{label}</button>)}</div>
    <div className={styles.results}>{visible.map(match=><ConnectionCard key={match.person.id} match={match}/>)}</div>{!visible.length&&<p className={styles.empty}>No people match this filter. Try another name or shared interest.</p>}
  </div>;
}
function ConnectionCard({match}:{match:DiscoveryMatch}) {
  const [relation,setRelation]=useState('Friend');const [busy,setBusy]=useState(false);const [added,setAdded]=useState(match.alreadyConnected);const [error,setError]=useState('');
  useEffect(()=>setAdded(match.alreadyConnected),[match.alreadyConnected]);
  const add=async()=>{setBusy(true);setError('');try{await addMyRelationship(match.person.id,relation,'FRIENDS');setAdded(true);}catch(e){setError((e as Error).message);}finally{setBusy(false);}};
  const gender=match.person.gender?.toLowerCase();const color=gender==='male'?'#2274c5':gender==='female'?'#d34e92':'#db8125';
  return <article className={styles.card}><header><span className={styles.avatar} style={{borderColor:color,color}} aria-hidden="true">{match.person.displayName.slice(0,1).toUpperCase()}</span><div><Link className={styles.name} href={`/people/${match.person.id}`}>{match.person.displayName}</Link><p>{match.person.location||'MyAaptha member'}</p></div>{added&&<span className={styles.connected}>In your network</span>}</header>
    <div className={styles.reasons}>{match.reasons.map(reason=><span key={reason}>{reason}</span>)}</div>
    {match.mutualConnections.length>0&&<details><summary>How you’re connected · {match.mutualConnections.length} visible paths</summary><ul>{match.mutualConnections.map(link=><li key={link.userId}><strong>You → <Link href={`/people/${link.userId}`}>{link.displayName}</Link> → {match.person.displayName}</strong><small>Your saved link: {link.yourRelationship} · Public link: {link.sharedRelationship}</small></li>)}</ul></details>}
    {match.sharedInterests.length>0&&<p className={styles.common}>Common interests: {match.sharedInterests.join(' · ')}</p>}
    <footer><Link className="btn btn-secondary" href={`/people/${match.person.id}`}>View details</Link>{!added&&<><label className={styles.relation}><span className="sr-only">Relationship with {match.person.displayName}</span><select aria-label={`Relationship with ${match.person.displayName}`} value={relation} disabled={busy} onChange={e=>setRelation(e.target.value)}>{['Friend','Colleague','Relative','Mother','Father','Sister','Brother','Cousin','Other'].map(type=><option key={type}>{type}</option>)}</select></label><button className="btn btn-primary" type="button" disabled={busy} onClick={()=>void add()}>{busy?'Adding…':'Add connection'}</button></>}</footer>
    {error&&<p role="alert" className="error-message">{error}</p>}{added&&!match.alreadyConnected&&<p role="status">Connection added with Friends visibility.</p>}
  </article>;
}
