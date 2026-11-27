'use client';

import Link from 'next/link';
import WorkspaceIcon from './WorkspaceIcon';
import PageDiscover from './PageDiscover';
import {primaryNavigation} from '../lib/workspace-navigation';
import Image from 'next/image';
import type { Route } from 'next';
import { ReactNode, useEffect, useState, useRef } from 'react';
import { usePathname } from 'next/navigation';
import { logout, fetchApplicationSettings, hasAuthSession, ApplicationSettings, fetchUnreadNotificationCount, fetchSessionProfile } from '../lib/api';

const unsupportedControlCharacters = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
import {validateUploadMetadata} from '../lib/upload-security';

function useGlobalClientValidation() {
  useEffect(() => {
    const limits: Record<string, number> = { password: 128, email: 254, tel: 32, search: 200 };
    const configure = (root: ParentNode) => {
      const fields = Array.from(root.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('input,textarea'));
      if (root instanceof HTMLInputElement || root instanceof HTMLTextAreaElement) fields.unshift(root);
      fields.forEach(field => {
        if (field instanceof HTMLInputElement && ['file', 'checkbox', 'radio', 'date', 'datetime-local', 'month', 'time', 'color', 'range'].includes(field.type)) return;
        if (field.maxLength < 0) field.maxLength = field instanceof HTMLTextAreaElement ? 4000 : (limits[field.type] || 255);
      });
    };
    const validate = (field: HTMLInputElement | HTMLTextAreaElement) => {
      field.setCustomValidity('');
      const value = field.value;
      if (!value) return;
      if (unsupportedControlCharacters.test(value)) {
        field.setCustomValidity('Remove unsupported control characters.');
      } else if (field instanceof HTMLInputElement && field.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())) {
        field.setCustomValidity('Enter a valid email address.');
      } else if (field instanceof HTMLInputElement && field.type === 'tel') {
        const digits = value.replace(/\D/g, '');
        if (digits.length < 7 || digits.length > 15) field.setCustomValidity('Enter a valid phone number.');
      } else if (field instanceof HTMLInputElement && field.type === 'number' && value && !Number.isFinite(Number(value))) {
        field.setCustomValidity('Enter a valid number.');
      }
    };
    const onInput = (event: Event) => {
      const field = event.target;
      if (field instanceof HTMLInputElement || field instanceof HTMLTextAreaElement) validate(field);
    };
    const onFile = (event: Event) => {
      const field = event.target;
      if (!(field instanceof HTMLInputElement) || field.type !== 'file') return;
      for (const file of Array.from(field.files || [])) {
        let message = '';
        try{validateUploadMetadata(file);}catch(error){message=(error as Error).message;}
        if (message) {
          field.value = '';
          field.setCustomValidity(message);
          event.preventDefault();
          event.stopImmediatePropagation();
          field.reportValidity();
          return;
        }
      }
      field.setCustomValidity('');
    };
    const onSubmit = (event: Event) => {
      const form = event.target;
      if (!(form instanceof HTMLFormElement)) return;
      configure(form);
      form.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('input,textarea').forEach(validate);
      if (!form.checkValidity()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        form.reportValidity();
      }
    };
    configure(document);
    const observer = new MutationObserver(records => records.forEach(record => record.addedNodes.forEach(node => {
      if (node instanceof Element) configure(node);
    })));
    observer.observe(document.body, { childList: true, subtree: true });
    document.addEventListener('input', onInput, true);
    document.addEventListener('change', onFile, true);
    document.addEventListener('submit', onSubmit, true);
    return () => {
      observer.disconnect();
      document.removeEventListener('input', onInput, true);
      document.removeEventListener('change', onFile, true);
      document.removeEventListener('submit', onSubmit, true);
    };
  }, []);
}

const communityPaths = new Set(['/online-feed','/posts','/followers','/following','/discover','/messages']);
const navigationSections = [
  {label:'Community',items:primaryNavigation.filter(item=>communityPaths.has(item.href)).flatMap(item=>[
    {label:item.label,href:item.href},...item.tabs.filter(tab=>tab.href!==item.href)
  ])},
  {label:'My workspace',items:primaryNavigation.filter(item=>!communityPaths.has(item.href)).flatMap(item=>[
    {label:item.label,href:item.href},...item.tabs.filter(tab=>tab.href!==item.href)
  ])},
  {label:'Account & tools',items:[
    {label:'Notifications',href:'/notifications'}, {label:'Settings',href:'/settings'}, {label:'Blocked accounts',href:'/privacy'},
    {label:'Account sessions',href:'/session'}, {label:'AI controls',href:'/ai-activity'},
    {label:'Ask MyAaptha',href:'/help'}, {label:'My reports',href:'/reports'},
    {label:'Moderation',href:'/moderation'}
  ]}
];

export default function WorkspaceShell({ children }: { children: ReactNode }) {
  useGlobalClientValidation();
  const pathname = usePathname();
  const [expanded, setExpanded] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile,setIsMobile]=useState(false);
  const menuButton=useRef<HTMLButtonElement>(null);
  const sidebar=useRef<HTMLElement>(null);
  useEffect(()=>{const query=matchMedia('(max-width: 760px)');const update=()=>{setIsMobile(query.matches);if(!query.matches)setMobileOpen(false);};update();query.addEventListener('change',update);return()=>query.removeEventListener('change',update);},[]);
  const [upload, setUpload] = useState<{progress:number;status:string;message:string;fileName:string}|null>(null);
  const [signingOut,setSigningOut]=useState(false);
  const [unread,setUnread]=useState(0);
  const [isAdmin,setIsAdmin]=useState(false);
  useEffect(()=>{if(hasAuthSession())void fetchSessionProfile().then(user=>setIsAdmin(user.role==='ADMIN')).catch(()=>setIsAdmin(false));},[pathname]);
  const isPublic = ['/', '/auth', '/recover-account', '/verify-phone'].includes(pathname);

  useEffect(() => {
    setExpanded(window.localStorage.getItem('myaaptha.sidebar.expanded') !== 'false');
  }, []);

  useEffect(() => {
    if(isPublic||!hasAuthSession())return;
    let active=true;
    const apply=(s:ApplicationSettings)=>{document.documentElement.dataset.density=s.compactLayout?'compact':'comfortable';document.documentElement.dataset.motion=s.reducedMotion?'reduced':'normal';};
    const refresh=()=>{if(document.hidden)return;void fetchApplicationSettings().then(s=>{if(active)apply(s);}).catch(()=>{});void fetchUnreadNotificationCount().then(v=>{if(active)setUnread(v.count);}).catch(()=>{});};
    const changed=(event:Event)=>apply((event as CustomEvent<ApplicationSettings>).detail);
    refresh();window.addEventListener('focus',refresh);document.addEventListener('visibilitychange',refresh);window.addEventListener('myaaptha:settings-updated',changed);
    const timer=window.setInterval(()=>{if(!document.hidden)void fetchUnreadNotificationCount().then(v=>{if(active)setUnread(v.count);}).catch(()=>{});},30000);
    return()=>{active=false;clearInterval(timer);window.removeEventListener('focus',refresh);document.removeEventListener('visibilitychange',refresh);window.removeEventListener('myaaptha:settings-updated',changed);};
  },[isPublic,pathname]);
  useEffect(()=>{if(!mobileOpen)return;const previousOverflow=document.body.style.overflow;document.body.style.overflow='hidden';sidebar.current?.querySelector<HTMLElement>('a,button')?.focus();const close=(event:KeyboardEvent)=>{if(event.key==='Escape'){setMobileOpen(false);menuButton.current?.focus();}if(event.key==='Tab'){const items=Array.from(sidebar.current?.querySelectorAll<HTMLElement>('a[href],button:not(:disabled)')||[]);const first=items[0],last=items[items.length-1];if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}}};window.addEventListener('keydown',close);return()=>{document.body.style.overflow=previousOverflow;window.removeEventListener('keydown',close);};},[mobileOpen]);
  useEffect(() => {setMobileOpen(false);}, [pathname]);
  useEffect(()=>{let timer:number|undefined;const listener=(event:Event)=>{const detail=(event as CustomEvent<{progress:number;status:string;message:string;fileName:string}>).detail;setUpload(detail);if(detail.status==='complete')timer=window.setTimeout(()=>setUpload(null),3500);};window.addEventListener('myaaptha:upload-progress',listener);return()=>{window.removeEventListener('myaaptha:upload-progress',listener);if(timer)window.clearTimeout(timer);};},[]);

  if (isPublic) return children;

  const toggle = () => {
    if (window.innerWidth <= 760) return setMobileOpen(value => !value);
    setExpanded(value => {
      window.localStorage.setItem('myaaptha.sidebar.expanded', String(!value));
      return !value;
    });
  };
  const signOut=()=>{setSigningOut(true);logout();window.location.replace('/auth');};

  return <div className={`workspace-shell ${expanded ? 'nav-expanded' : 'nav-collapsed'}`}>
    <a className="skip-to-content" href="#workspace-main">Skip to content</a>
    {upload&&<section className={`global-upload-status upload-${upload.status}`} role="status" aria-live="polite"><div><strong>{upload.message}</strong><span>{upload.fileName}</span></div><b>{upload.progress}%</b><progress max="100" value={upload.progress}>{upload.progress}%</progress></section>}
    <header className="workspace-topbar">
      <button ref={menuButton} className="workspace-menu-button" onClick={toggle} aria-label="Toggle main menu" aria-expanded={isMobile ? mobileOpen : expanded} aria-controls="workspace-navigation"><WorkspaceIcon name="menu" /></button>
      <Link href="/dashboard" className="workspace-brand" aria-label="MyAaptha home"><Image src="/myaaptha-logo-256.webp" unoptimized width={38} height={38} alt="" priority /><strong>MyAaptha</strong></Link>
      <PageDiscover page={pathname}/>
    </header>
    <aside ref={sidebar} id="workspace-navigation" inert={isMobile&&!mobileOpen} className={`workspace-sidebar ${mobileOpen ? 'mobile-open' : ''}`} aria-label="Main navigation">
      {navigationSections.map(section => <section className="workspace-nav-section" key={section.label}><h2>{section.label}</h2><nav>{section.items.filter(item=>item.href!=='/discover').map(item => <Link key={item.href} href={item.href as Route} title={item.label} aria-current={pathname===item.href?"page":undefined} className={pathname===item.href ? 'active' : ''}><span aria-hidden="true"><WorkspaceIcon name={item.href} /></span><b>{item.label}{item.href==='/notifications'&&unread>0&&<span className="nav-unread">{unread>99?'99+':unread}</span>}</b></Link>)}</nav></section>)}
      {isAdmin&&<section className="workspace-nav-section"><h2>Administration</h2><nav><Link href={'/security-reports' as Route} className={pathname==='/security-reports'?'active':''}><span><WorkspaceIcon name="/security-reports" /></span><b>Security & errors</b></Link><Link href={'/project-inputs' as Route} className={pathname==='/project-inputs'?'active':''}><span><WorkspaceIcon name="/settings" /></span><b>Inputs needed</b></Link></nav></section>}
      <button type="button" className="workspace-sidebar-sign-out" disabled={signingOut} onClick={()=>void signOut()}><span><WorkspaceIcon name="logout" /></span><b>{signingOut?'Signing out...':'Sign out'}</b></button>
    </aside>
    {mobileOpen && <button className="workspace-scrim" onClick={() => setMobileOpen(false)} aria-label="Close navigation" />}
    <div id="workspace-main" tabIndex={-1} className="workspace-content">{children}</div>
  </div>;
}
