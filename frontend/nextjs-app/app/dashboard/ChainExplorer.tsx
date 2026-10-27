'use client';
import InfoTip from '../components/InfoTip';

import Link from 'next/link';
import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { buildChain, type Person, type Edge } from './chain-layout';
import styles from './ChainExplorer.module.css';

export default function ChainExplorer({ people, edges, root }: { people: Person[]; edges: Edge[]; root: number }) {
  const [expanded, setExpanded] = useState(() => new Set([root]));
  const [selected, setSelected] = useState<number | null>(null);
  const [zoom, setZoom] = useState(1);
  const [query, setQuery] = useState('');
  const viewport = useRef<HTMLDivElement>(null);
  const drag = useRef<{ x: number; y: number; left: number; top: number } | null>(null);
  const graph = useMemo(() => buildChain(people, edges, root, expanded), [people, edges, root, expanded]);
  const width = Math.max(600, ...Array.from(graph.positions.values(), p => p.x + 250));
  const height = Math.max(400, ...Array.from(graph.positions.values(), p => p.y + 100));
  const person = people.find(item => item.id === selected);
  const fit = () => { if (viewport.current) { setZoom(Math.min(1, (viewport.current.clientWidth - 24) / width, (viewport.current.clientHeight - 24) / height)); viewport.current.scrollTo(0, 0); } };
  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const resize = () => { setZoom(Math.min(1, (element.clientWidth - 24) / width, (element.clientHeight - 24) / height)); element.scrollTo(0, 0); };
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(element);
    return () => observer.disconnect();
  }, [width, height]);
  const toggle = (id: number) => setExpanded(previous => { const next = new Set(previous); if (next.has(id)) next.delete(id); else next.add(id); return next; });
  const reveal = (id: number) => {
    const next = new Set(expanded);
    let parent = graph.parents.get(id);
    while (parent !== undefined) { next.add(parent); parent = graph.parents.get(parent); }
    setExpanded(next); setSelected(id); setQuery('');
  };
  const color = (gender?: string | null) => ['male','man'].includes(gender?.trim().toLowerCase()||'') ? '#3876d6' : ['female','woman'].includes(gender?.trim().toLowerCase()||'') ? '#d53e83' : '#64748b';
  return <section className={styles.explorer} aria-label="Relationship chain explorer">
    <header className={styles.header}><div><span className={styles.eyebrow}>PEOPLE & CONNECTIONS</span><div className="inline-help-heading"><h2>Your relationship chain</h2><InfoTip label="Relationship chain help"><p>Click a filled circle to expand or collapse its branch. Outlined circles are end nodes in the available chain. Select a name for details. Drag the background to move around; use Fit entire chain to reset the view.</p></InfoTip></div></div><span>{people.length} people</span></header>
    <div className={styles.toolbar}>
      <label>Find a person<input type="search" placeholder="Search by name" value={query} onChange={event => setQuery(event.target.value)}/></label>
      <button type="button" onClick={() => setExpanded(new Set(people.map(item => item.id)))}>Expand all</button>
      <button type="button" onClick={() => setExpanded(new Set([root]))}>Reset branches</button>
      <button type="button" onClick={fit}>Fit entire chain</button>
      <button type="button" aria-label="Zoom out" onClick={() => setZoom(value => Math.max(.02, value / 1.25))}>−</button><output>{Math.round(zoom * 100)}%</output><button type="button" aria-label="Zoom in" onClick={() => setZoom(value => Math.min(2, value * 1.25))}>+</button>
    </div>
    {query.trim() && <div className={styles.results}>{people.filter(item => item.name.toLowerCase().includes(query.trim().toLowerCase())).map(item => <button type="button" key={item.id} onClick={() => reveal(item.id)}>{item.name}</button>)}{!people.some(item => item.name.toLowerCase().includes(query.trim().toLowerCase())) && <p>No matching people.</p>}</div>}
    <div className={styles.body}>
      <div className={styles.viewport} ref={viewport} tabIndex={0} aria-label="Scrollable relationship tree. Drag the background or use scrollbars to explore." onPointerDown={event => { if ((event.target as HTMLElement).closest('button')) return; drag.current = { x: event.clientX, y: event.clientY, left: event.currentTarget.scrollLeft, top: event.currentTarget.scrollTop }; event.currentTarget.setPointerCapture(event.pointerId); }} onPointerMove={event => { if (drag.current) { event.currentTarget.scrollLeft = drag.current.left - event.clientX + drag.current.x; event.currentTarget.scrollTop = drag.current.top - event.clientY + drag.current.y; } }} onPointerUp={() => { drag.current = null; }} onPointerCancel={() => { drag.current = null; }}>
        <div style={{ width: width * zoom, height: height * zoom }}><div className={styles.canvas} style={{ width, height, transform: `scale(${zoom})` }}>
          <svg width={width} height={height} className={styles.edges} aria-hidden="true">{edges.map((edge, index) => { const a = graph.positions.get(edge.source), b = graph.positions.get(edge.target); if (!a || !b) return null; return <path key={index} d={`M ${a.x + 12} ${a.y + 18} C ${(a.x + b.x) / 2} ${a.y + 18}, ${(a.x + b.x) / 2} ${b.y + 18}, ${b.x + 12} ${b.y + 18}`}/>; })}</svg>
          {people.map(item => { const point = graph.positions.get(item.id); if (!point) return null; const count = graph.children.get(item.id)?.length || 0; return <div key={item.id} className={`${styles.node} ${selected === item.id ? styles.selected : ''}`} style={{ left: point.x, top: point.y }}>
            {count?<button type="button" className={styles.branchDot} style={{'--branch-color':color(item.gender || (['mother','wife','sister','daughter','grandmother','aunt','niece'].includes(item.relationship?.type?.toLowerCase() || '') ? 'female' : ['father','husband','brother','son','grandfather','uncle','nephew'].includes(item.relationship?.type?.toLowerCase() || '') ? 'male' : null))} as CSSProperties} aria-expanded={expanded.has(item.id)} aria-label={`${expanded.has(item.id)?'Collapse':'Expand'} branch for ${item.name}`} title={`${count} branches available`} onClick={()=>toggle(item.id)}>{expanded.has(item.id)?'−':'+'}</button>:<span className={styles.branchDot} style={{'--branch-color':color(item.gender || (['mother','wife','sister','daughter','grandmother','aunt','niece'].includes(item.relationship?.type?.toLowerCase() || '') ? 'female' : ['father','husband','brother','son','grandfather','uncle','nephew'].includes(item.relationship?.type?.toLowerCase() || '') ? 'male' : null))} as CSSProperties} role="img" aria-label={`${item.name}: end of available chain`} title="End of available chain"/>}
            <button type="button" className={styles.identity} onClick={() => setSelected(item.id)} aria-label={`View details for ${item.name}`}><span><strong>{item.name}</strong><small>{item.id === root ? 'You' : item.relationship?.type || 'Connection'}</small></span></button>
          </div>; })}
        </div></div>
      </div>
      {person && <aside className={styles.details} aria-label={`${person.name} details`}><button type="button" className={styles.close} onClick={() => setSelected(null)} aria-label="Close person details">×</button><span className={styles.eyebrow}>PERSON DETAILS</span><h3>{person.name}</h3><p>{person.id === root ? 'You' : person.relationship?.type}</p><dl><dt>Gender</dt><dd>{person.gender || 'Not specified'}</dd>{person.relationship?.contactPhone && <><dt>Phone</dt><dd>{person.relationship.contactPhone}</dd></>}{person.relationship?.contactEmail && <><dt>Email</dt><dd>{person.relationship.contactEmail}</dd></>}</dl><Link href={person.id === root ? '/profile' : `/people/${person.id}`}>Open full profile ↗</Link>{Boolean(graph.children.get(person.id)?.length) && <button type="button" onClick={() => toggle(person.id)}>{expanded.has(person.id) ? 'Collapse chain' : 'Expand chain'}</button>}<p className={styles.note}>Only connections available in your network are shown.</p></aside>}
    </div>
    <footer className={styles.legend}><span><i style={{ background: '#3876d6' }}/>Men</span><span><i style={{ background: '#d53e83' }}/>Women</span><span><i style={{ background: '#64748b' }}/>Other / unspecified</span><span><i style={{background:'#64748b'}}/>Has branches</span><span><i style={{background:'white',border:'2px solid #64748b'}}/>End node</span><small>{graph.positions.size} of {people.length} visible · Drag to pan</small></footer>
  </section>;
}
