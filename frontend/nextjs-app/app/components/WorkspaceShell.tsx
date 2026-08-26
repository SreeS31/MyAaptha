'use client';

import Link from 'next/link';
import Image from 'next/image';
import type { Route } from 'next';
import { FormEvent, ReactNode, useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';

const navigationSections = [
  {
    label: 'Connect',
    items: [
      { href: '/dashboard', icon: '⌂', label: 'Home dashboard' },
      { href: '/messages', icon: '✉', label: 'Private messages' },
      { href: '/circles', icon: '◎', label: 'My circles' },
      { href: '/circle-search', icon: '⌕', label: 'Find people & circles' },
      { href: '/notifications', icon: '♢', label: 'Notifications' },
    ],
  },
  {
    label: 'Personal assistant',
    items: [
      { href: '/feed', icon: '✎', label: 'Diary & memories' },
      { href: '/timeline', icon: '◇', label: 'Life timeline' },
      { href: '/finance', icon: '₹', label: 'Money & insights' },
    ],
  },
  {
    label: 'Account',
    items: [
      { href: '/trust', icon: '★', label: 'Trust center' },
      { href: '/profile', icon: '♙', label: 'My profile' },
      { href: '/privacy', icon: '⚙', label: 'Privacy & settings' },
      { href: '/session', icon: '◌', label: 'Account sessions' },
    ],
  },
  {
    label: 'Safety & control',
    items: [
      { href: '/reports', icon: '⚑', label: 'My reports' },
      { href: '/moderation', icon: '◆', label: 'Moderation' },
    ],
  },
];

const utilities = [
  { href: '/circle-search', icon: '⌕', label: 'Search' },
  { href: '/dashboard#projects', icon: '□', label: 'Schedule' },
  { href: '/notifications', icon: '♢', label: 'Notifications' },
  { href: '/dashboard#relationships', icon: '♧', label: 'Contacts' },
  { href: '/privacy', icon: '⚙', label: 'Settings' },
];

function isSelected(pathname: string, href: string) {
  const path = href.split('#')[0];
  return pathname === path || (path !== '/dashboard' && pathname.startsWith(`${path}/`));
}

export default function WorkspaceShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [expanded, setExpanded] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [upload, setUpload] = useState<{progress:number;status:string;message:string;fileName:string}|null>(null);
  const isPublic = pathname === '/' || pathname === '/auth';

  useEffect(() => {
    setExpanded(window.localStorage.getItem('circlenet.sidebar.expanded') !== 'false');
  }, []);

  useEffect(() => setMobileOpen(false), [pathname]);
  useEffect(()=>{let timer:number|undefined;const listener=(event:Event)=>{const detail=(event as CustomEvent<{progress:number;status:string;message:string;fileName:string}>).detail;setUpload(detail);if(detail.status==='complete')timer=window.setTimeout(()=>setUpload(null),3500);};window.addEventListener('circlenet:upload-progress',listener);return()=>{window.removeEventListener('circlenet:upload-progress',listener);if(timer)window.clearTimeout(timer);};},[]);

  if (isPublic) return children;

  const toggle = () => {
    if (window.innerWidth <= 760) return setMobileOpen(value => !value);
    setExpanded(value => {
      window.localStorage.setItem('circlenet.sidebar.expanded', String(!value));
      return !value;
    });
  };
  const search = (event: FormEvent) => {
    event.preventDefault();
    router.push(query.trim() ? `/circle-search?q=${encodeURIComponent(query.trim())}` : '/circle-search');
  };

  return <div className={`workspace-shell ${expanded ? 'nav-expanded' : 'nav-collapsed'}`}>
    {upload&&<section className={`global-upload-status upload-${upload.status}`} role="status" aria-live="polite"><div><strong>{upload.message}</strong><span>{upload.fileName}</span></div><b>{upload.progress}%</b><progress max="100" value={upload.progress}>{upload.progress}%</progress></section>}
    <header className="workspace-topbar">
      <button className="workspace-menu-button" onClick={toggle} aria-label="Toggle main menu" aria-expanded={expanded || mobileOpen}>☰</button>
      <Link href="/dashboard" className="workspace-brand" aria-label="CircleNet home"><Image src="/circlenet-logo.png" width={38} height={38} alt="" priority /><strong>CircleNet</strong></Link>
      <form className="workspace-global-search" onSubmit={search} role="search">
        <span aria-hidden="true">⌕</span><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Search people, circles and messages" aria-label="Search CircleNet" />
        <button aria-label="Open search filters" type="submit">☷</button>
      </form>
      <nav className="workspace-top-actions" aria-label="Account tools"><Link href="/notifications" aria-label="Notifications">♢</Link><Link href="/privacy" aria-label="Settings">⚙</Link><Link href="/profile" className="workspace-account" aria-label="Profile">ME</Link></nav>
    </header>
    <aside className={`workspace-sidebar ${mobileOpen ? 'mobile-open' : ''}`} aria-label="Main navigation">
      <Link className="workspace-primary-action" href="/feed"><span>＋</span><b>New diary entry</b></Link>
      {navigationSections.map(section => <section className="workspace-nav-section" key={section.label}><h2>{section.label}</h2><nav>{section.items.map(item => <Link key={item.href} href={item.href as Route} title={item.label} className={isSelected(pathname, item.href) ? 'active' : ''}><span>{item.icon}</span><b>{item.label}</b></Link>)}</nav></section>)}
      <small>Private by design</small>
    </aside>
    {mobileOpen && <button className="workspace-scrim" onClick={() => setMobileOpen(false)} aria-label="Close navigation" />}
    <div className="workspace-content">{children}</div>
    <aside className="workspace-utilities" aria-label="Quick tools">{utilities.map(item => <Link key={item.label} href={item.href as Route} title={item.label} aria-label={item.label}><span>{item.icon}</span></Link>)}</aside>
  </div>;
}
