'use client';

import Link from 'next/link';
import { FormEvent, ReactNode, Suspense, useCallback, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  CirclePost, DirectConversation, DirectMessage, fetchDirectConversations, fetchMyCircles,
  fetchMyRelationships, hasAuthSession, isUnauthorizedError, NetworkCircle, NetworkPerson,
  NetworkRelationship, searchCirclePosts, searchDirectMessages, searchNetworkPeople,
} from '../lib/api';

type GlobalResults = {
  people: NetworkPerson[];
  relationships: NetworkRelationship[];
  circles: NetworkCircle[];
  circleMessages: Array<{ circle: NetworkCircle; post: CirclePost }>;
  privateMessages: Array<{ conversation: DirectConversation; message: DirectMessage }>;
};
const emptyGlobalResults: GlobalResults = { people: [], relationships: [], circles: [], circleMessages: [], privateMessages: [] };
const includes = (value: string | null | undefined, query: string) => Boolean(value?.toLocaleLowerCase().includes(query));

function CircleSearchContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const globalQuery = searchParams.get('q')?.trim() || '';
  const [circles, setCircles] = useState<NetworkCircle[]>([]);
  const [circleId, setCircleId] = useState('');
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<CirclePost[]>([]);
  const [searched, setSearched] = useState(false);
  const [globalResults, setGlobalResults] = useState<GlobalResults>(emptyGlobalResults);
  const [globalLoading, setGlobalLoading] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const values = await fetchMyCircles();
      setCircles(values);
      if (values.length) setCircleId(current => current || searchParams.get('circleId') || String(values[0].id));
    } catch (caught) {
      if (isUnauthorizedError(caught)) router.replace('/auth'); else setError((caught as Error).message);
    }
  }, [router, searchParams]);

  useEffect(() => { if (!hasAuthSession()) router.replace('/auth'); else void load(); }, [load, router]);
  useEffect(() => {
    if (!globalQuery) { setGlobalResults(emptyGlobalResults); setGlobalLoading(false); return; }
    let cancelled = false;
    const run = async () => {
      setGlobalLoading(true); setError('');
      try {
        const [people, relationships, availableCircles, conversations] = await Promise.all([
          searchNetworkPeople(globalQuery), fetchMyRelationships(), fetchMyCircles(), fetchDirectConversations(),
        ]);
        const normalized = globalQuery.toLocaleLowerCase();
        const matchingRelationships = relationships.filter(item =>
          includes(item.person.displayName, normalized) || includes(item.type, normalized) ||
          includes(item.contactPhone, normalized) || includes(item.contactEmail, normalized));
        const matchingCircles = availableCircles.filter(circle =>
          includes(circle.name, normalized) || includes(circle.description, normalized) ||
          circle.members.some(member => includes(member.person.displayName, normalized)));
        const circleSearches = await Promise.allSettled(availableCircles.map(async circle =>
          (await searchCirclePosts(circle.id, globalQuery)).map(post => ({ circle, post }))));
        const directSearches = await Promise.allSettled(conversations.map(async conversation =>
          (await searchDirectMessages(conversation.userId, globalQuery)).map(message => ({ conversation, message }))));
        if (!cancelled) {
          setCircles(availableCircles);
          setGlobalResults({
            people, relationships: matchingRelationships, circles: matchingCircles,
            circleMessages: circleSearches.flatMap(result => result.status === 'fulfilled' ? result.value : []),
            privateMessages: directSearches.flatMap(result => result.status === 'fulfilled' ? result.value : []),
          });
        }
      } catch (caught) {
        if (isUnauthorizedError(caught)) router.replace('/auth'); else if (!cancelled) setError((caught as Error).message);
      } finally { if (!cancelled) setGlobalLoading(false); }
    };
    void run();
    return () => { cancelled = true; };
  }, [globalQuery, router]);

  const search = async (event: FormEvent) => {
    event.preventDefault(); if (!circleId || !query.trim()) return; setError('');
    try { setResults(await searchCirclePosts(Number(circleId), query.trim())); setSearched(true); }
    catch (caught) { setError((caught as Error).message); }
  };
  const globalCount = Object.values(globalResults).reduce((total, values) => total + values.length, 0);

  return <main className="container circle-search-page">
    <header className="network-header"><div><p className="eyebrow">SEARCH</p><h1>Search MyAaptha</h1><p>Find people, relationships, circles, and messages across your account.</p></div><Link href="/dashboard" className="btn btn-secondary">Dashboard</Link></header>
    {error && <p className="network-message error-message">{error}</p>}
    {globalQuery && <section className="card global-search-results" aria-live="polite">
      <header><div><p className="eyebrow">ALL MYAAPTHA</p><h2>Results for &quot;{globalQuery}&quot;</h2></div>{!globalLoading && <span>{globalCount} {globalCount === 1 ? 'match' : 'matches'}</span>}</header>
      {globalLoading ? <div className="social-empty"><p>Searching people, circles, and messages...</p></div> : <>
        {globalResults.people.length > 0 && <GlobalGroup title="People">{globalResults.people.map(person => <SearchResult key={`person-${person.id}`} title={person.displayName} detail={[person.location, person.phoneNumber].filter(Boolean).join(' | ') || 'MyAaptha member'} action="View profile" onOpen={() => router.push(`/people/${person.id}`)} />)}</GlobalGroup>}
        {globalResults.relationships.length > 0 && <GlobalGroup title="Relationships">{globalResults.relationships.map(item => <SearchResult key={`relationship-${item.id}`} title={item.person.displayName} detail={item.type} action="Open network" onOpen={() => router.push('/dashboard#relationships')} />)}</GlobalGroup>}
        {globalResults.circles.length > 0 && <GlobalGroup title="Circles">{globalResults.circles.map(circle => <SearchResult key={`circle-${circle.id}`} title={circle.name} detail={circle.description || `${circle.members.length} members`} action="Open circle" onOpen={() => router.push(`/dashboard?circleId=${circle.id}`)} />)}</GlobalGroup>}
        {globalResults.circleMessages.length > 0 && <GlobalGroup title="Circle messages">{globalResults.circleMessages.map(({ circle, post }) => <SearchResult key={`circle-message-${post.id}`} title={circle.name} detail={`${post.authorName}: ${post.message || post.attachmentName || 'Attachment'}`} action="Open message" onOpen={() => router.push(`/dashboard?circleId=${circle.id}`)} />)}</GlobalGroup>}
        {globalResults.privateMessages.length > 0 && <GlobalGroup title="Private messages">{globalResults.privateMessages.map(({ conversation, message }) => <SearchResult key={`private-message-${message.id}`} title={conversation.displayName} detail={message.message || message.attachmentName || 'Attachment'} action="Open chat" onOpen={() => router.push(`/dashboard?messageUserId=${conversation.userId}`)} />)}</GlobalGroup>}
        {!globalCount && <div className="social-empty"><h2>No matches found</h2><p>Try another name, word, phone number, or attachment name.</p></div>}
      </>}
    </section>}
    <section className="page-search-section"><header><p className="eyebrow">THIS PAGE</p><h2>Search within one circle</h2></header>
      <form className="card circle-search-form" onSubmit={search}><label><span>Circle</span><select required value={circleId} onChange={event => { setCircleId(event.target.value); setResults([]); setSearched(false); }}><option value="">Choose a circle</option>{circles.map(circle => <option key={circle.id} value={circle.id}>{circle.name}</option>)}</select></label><label><span>Words or attachment name</span><input required type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Search this circle" /></label><button className="btn btn-primary">Search</button></form>
      <section className="card circle-search-results">{results.map(post => <article key={post.id}><span className="conversation-avatar">{post.authorPhoto ? <img src={post.authorPhoto} alt="" /> : post.authorName.charAt(0).toUpperCase()}</span><span><strong>{post.authorName}</strong><p>{post.message || post.attachmentName || 'Attachment'}</p><small>{new Date(post.createdAt).toLocaleString()}{post.editedAt ? ' | edited' : ''}</small></span><button className="btn btn-secondary" onClick={() => router.push(`/dashboard?circleId=${post.circleId}`)}>Open circle</button></article>)}{searched && !results.length && <div className="social-empty"><h2>No matching messages</h2><p>Try a different word or attachment name.</p></div>}{!searched && <div className="social-empty"><p>Choose a circle and enter a search term.</p></div>}</section>
    </section>
  </main>;
}

function GlobalGroup({ title, children }: { title: string; children: ReactNode }) {
  return <section className="global-result-group"><h3>{title}</h3><div>{children}</div></section>;
}
function SearchResult({ title, detail, action, onOpen }: { title: string; detail: string; action: string; onOpen: () => void }) {
  return <article><span><strong>{title}</strong><p>{detail}</p></span><button type="button" className="btn btn-secondary" onClick={onOpen}>{action}</button></article>;
}
export default function CircleSearchPage() {
  return <Suspense fallback={<main className="container circle-search-page"><div className="card social-empty"><p>Loading search...</p></div></main>}><CircleSearchContent /></Suspense>;
}
