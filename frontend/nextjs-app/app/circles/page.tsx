'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { fetchMyCircles, hasAuthSession, isUnauthorizedError, NetworkCircle } from '../lib/api';

export default function CirclesPage() {
  const router = useRouter();
  const [circles, setCircles] = useState<NetworkCircle[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    try { setCircles(await fetchMyCircles()); setError(''); }
    catch (caught) { if (isUnauthorizedError(caught)) router.replace('/auth'); else setError((caught as Error).message); }
    finally { setLoading(false); }
  }, [router]);
  useEffect(() => { if (!hasAuthSession()) router.replace('/auth'); else void load(); }, [load, router]);
  const visible = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return circles;
    return circles.filter(circle => circle.name.toLowerCase().includes(term) || circle.description?.toLowerCase().includes(term) || circle.members.some(member => member.person.displayName.toLowerCase().includes(term)));
  }, [circles, query]);

  return <main className="container circles-page">
    <header className="network-header circles-header"><div><p className="eyebrow">MY CIRCLES</p><h1>Circles</h1><p>See every circle you belong to, its members, permissions, and conversations.</p></div><nav><Link href="/circle-search" className="btn btn-secondary">Search messages</Link><Link href="/dashboard#circles" className="btn btn-primary">Create circle</Link></nav></header>
    {error && <p className="network-message error-message" role="alert">{error}</p>}
    <section className="card circles-toolbar"><label><span aria-hidden="true">⌕</span><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Find a circle or member" /></label><strong>{visible.length} circle{visible.length === 1 ? '' : 's'}</strong></section>
    <section className="circles-directory" aria-live="polite">
      {visible.map(circle => <article className="card circle-directory-card" key={circle.id}>
        <header><span className="circle-directory-icon">{circle.name.charAt(0).toUpperCase()}</span><div><h2>{circle.name}</h2><p>{circle.description || 'Private MyAaptha group'}</p></div><span className={`circle-access-badge ${circle.currentUserAdmin ? 'admin' : ''}`}>{circle.currentUserAdmin ? 'Admin' : 'Member'}</span></header>
        <dl><div><dt>Members</dt><dd>{circle.members.length}</dd></div><div><dt>Created by</dt><dd>{circle.ownerName}</dd></div><div><dt>Posting</dt><dd>{circle.currentUserCanPost ? 'Allowed' : 'Admins only'}</dd></div></dl>
        <div className="circle-directory-members">{circle.members.slice(0, 6).map(member => <span key={member.person.id} title={`${member.person.displayName}${member.admin ? ' · Admin' : ''}`}>{member.person.profilePhoto ? <img src={member.person.profilePhoto} alt="" /> : member.person.displayName.charAt(0).toUpperCase()}</span>)}{circle.members.length > 6 && <b>+{circle.members.length - 6}</b>}<small>{circle.members.slice(0, 3).map(member => member.person.displayName).join(', ')}{circle.members.length > 3 ? ` and ${circle.members.length - 3} more` : ''}</small></div>
        <footer><Link className="btn btn-primary" href={`/dashboard?circleId=${circle.id}`}>Open full circle</Link><Link className="btn btn-secondary" href={`/circle-search?circleId=${circle.id}`}>Search messages</Link></footer>
      </article>)}
      {!loading && !visible.length && <div className="card social-empty"><h2>{query ? 'No matching circles' : 'No circles yet'}</h2><p>{query ? 'Try a circle name, description, or member name.' : 'Create your first circle or ask a circle admin to add you.'}</p></div>}
      {loading && <div className="card social-empty"><p>Loading all circles…</p></div>}
    </section>
  </main>;
}
