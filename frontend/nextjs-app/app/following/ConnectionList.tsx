'use client';
import Link from 'next/link';
import {useEffect,useState} from 'react';
import {fetchFollowConnections,unfollowRoleModel,TrustedPerson} from '../lib/api';
import PageHeading from '../components/PageHeading';

export default function ConnectionList({kind='following'}:{kind?:'following'|'followers'}) {
  const [page,setPage]=useState(0),[people,setPeople]=useState<TrustedPerson[]>([]),[more,setMore]=useState(false),[loading,setLoading]=useState(true),[error,setError]=useState(''),[revision,setRevision]=useState(0),[busy,setBusy]=useState<number|null>(null);
  const [query,setQuery]=useState('');
  useEffect(()=>{let active=true;setPeople([]);setMore(false);setLoading(true);setError('');fetchFollowConnections(kind,page).then(result=>{if(active){setPeople(result.people);setMore(result.hasNext);}}).catch(e=>{if(active)setError(e.message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[kind,page,revision]);
  const visible=people.filter(person=>person.displayName.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()));
  return <main className="container following-page community-page">
    <PageHeading title={kind==='following'?'Following':'Followers'} help="Role Model connections do not unlock private diary entries or contact details."/>
    <section className="community-intro"><span className="community-mark" aria-hidden="true">◎</span><div><h2>{kind==='following'?'People who inspire you':'Your community, connected'}</h2><p>{kind==='following'?'Keep up with the Role Models you choose to follow.':'Meet the people who follow your shared moments.'}</p></div><Link className="btn btn-primary" href="/trust">Discover Role Models</Link></section>
    <nav className="community-tabs" aria-label="Your community"><Link href="/posts">My posts</Link><Link href="/followers" aria-current={kind==='followers'?'page':undefined}>Followers</Link><Link href="/following" aria-current={kind==='following'?'page':undefined}>Following</Link></nav>
    <div className="community-list-tools"><label htmlFor="connection-search">Search this page</label><input id="connection-search" type="search" value={query} onChange={event=>setQuery(event.target.value)} placeholder="Search by name" maxLength={100}/></div>
    {error&&<div className="network-message error-message" role="alert">{error}<button type="button" className="btn btn-secondary" onClick={()=>setRevision(value=>value+1)}>Try again</button></div>}
    {loading?<p role="status">Loading people…</p>:!error&&<>
      <section className="follow-people-grid" aria-label={kind==='following'?'People you follow':'People following you'}>{visible.map(person=><article className="follow-person-card" key={person.userId}><span className="follow-avatar" aria-hidden="true">{person.displayName.trim().split(/\s+/).slice(0,2).map(word=>word[0]).join('')||'?'}</span><div><Link href={`/people/${person.userId}`}>{person.displayName}</Link><small>{kind==='following'?'You follow this Role Model':'Follows you'}</small></div>{kind==='following'?<button className="btn btn-secondary" disabled={busy!==null} onClick={async()=>{setBusy(person.userId);try{await unfollowRoleModel(person.userId);setRevision(value=>value+1);}catch(e){setError((e as Error).message);}finally{setBusy(null);}}}>{busy===person.userId?'Updating…':'Unfollow'}</button>:<Link className="btn btn-secondary" href={`/people/${person.userId}`}>View profile</Link>}</article>)}</section>
      {!visible.length&&<div className="follow-empty"><h2>{people.length?'No matching names':kind==='following'?'Find your inspiration':'Your community grows here'}</h2><p>{people.length?'Try another name or clear your search.':kind==='following'?'Discover a Role Model and choose who you follow.':'People who follow you will appear here.'}</p></div>}
      <nav className="community-pagination" aria-label="Follow list pages"><button className="btn btn-secondary" disabled={!page} onClick={()=>{setQuery('');setPage(value=>value-1);}}>Previous</button><span>Page {page+1}</span><button className="btn btn-secondary" disabled={!more} onClick={()=>{setQuery('');setPage(value=>value+1);}}>Next</button></nav>
    </>}
  </main>;
}
