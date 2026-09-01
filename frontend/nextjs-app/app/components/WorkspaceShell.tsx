'use client';

import Link from 'next/link';
import Image from 'next/image';
import type { Route } from 'next';
import { FormEvent, ReactNode, useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { logout } from '../lib/api';

const unsupportedControlCharacters = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
const blockedUploadExtensions = new Set(['exe','dll','com','scr','msi','msp','bat','cmd','ps1','psm1','vbs','vbe','js','jse','jar','war','class','sh','bash','zsh','php','phtml','asp','aspx','cgi','pl','py','rb','html','htm','hta','svg','apk','ipa','dmg','iso','img','deb','rpm','reg','lnk','url','scf','cpl','sys','drv','ocx','cab','appx','appxbundle','xll','doc','xls','ppt','docm','dotm','xlsm','xltm','pptm','potm','ppam','sldm']);
const allowedUploadExtensions = new Set(['jpg','jpeg','jfif','png','webp','gif','bmp','tif','tiff','avif','heic','heif','ico','psd','dng','cr2','nef','arw','mp3','m4a','aac','wav','flac','ogg','oga','opus','amr','aif','aiff','mid','midi','mp4','m4v','mov','avi','mkv','webm','mpeg','mpg','ogv','3gp','3g2','flv','pdf','txt','csv','vcf','docx','xlsx','pptx','glb','gltf','obj','stl','fbx','3mf','dae','ply','usdz','blend']);

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
        const parts = file.name.toLowerCase().split('.');
        const extension = parts.length > 1 ? parts.at(-1)! : '';
        const unsafe = parts.slice(1).some(part => blockedUploadExtensions.has(part));
        let message = '';
        if (!extension || unsafe || !allowedUploadExtensions.has(extension)) message = 'This file type is blocked for security reasons.';
        else if (!file.size || file.size > 25 * 1024 * 1024) message = 'Files must be non-empty and 25 MB or smaller.';
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
      { href: '/health', icon: '♥', label: 'Health records' },
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
  useGlobalClientValidation();
  const pathname = usePathname();
  const router = useRouter();
  const [expanded, setExpanded] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [upload, setUpload] = useState<{progress:number;status:string;message:string;fileName:string}|null>(null);
  const [signingOut,setSigningOut]=useState(false);
  const isPublic = pathname === '/' || pathname === '/auth';

  useEffect(() => {
    setExpanded(window.localStorage.getItem('myaaptha.sidebar.expanded') !== 'false');
  }, []);

  useEffect(() => setMobileOpen(false), [pathname]);
  useEffect(()=>{let timer:number|undefined;const listener=(event:Event)=>{const detail=(event as CustomEvent<{progress:number;status:string;message:string;fileName:string}>).detail;setUpload(detail);if(detail.status==='complete')timer=window.setTimeout(()=>setUpload(null),3500);};window.addEventListener('myaaptha:upload-progress',listener);return()=>{window.removeEventListener('myaaptha:upload-progress',listener);if(timer)window.clearTimeout(timer);};},[]);

  if (isPublic) return children;

  const toggle = () => {
    if (window.innerWidth <= 760) return setMobileOpen(value => !value);
    setExpanded(value => {
      window.localStorage.setItem('myaaptha.sidebar.expanded', String(!value));
      return !value;
    });
  };
  const search = (event: FormEvent) => {
    event.preventDefault();
    router.push(query.trim() ? `/circle-search?q=${encodeURIComponent(query.trim())}` : '/circle-search');
  };
  const signOut=()=>{setSigningOut(true);logout();window.location.replace('/auth');};

  return <div className={`workspace-shell ${expanded ? 'nav-expanded' : 'nav-collapsed'}`}>
    {upload&&<section className={`global-upload-status upload-${upload.status}`} role="status" aria-live="polite"><div><strong>{upload.message}</strong><span>{upload.fileName}</span></div><b>{upload.progress}%</b><progress max="100" value={upload.progress}>{upload.progress}%</progress></section>}
    <header className="workspace-topbar">
      <button className="workspace-menu-button" onClick={toggle} aria-label="Toggle main menu" aria-expanded={expanded || mobileOpen}>☰</button>
      <Link href="/dashboard" className="workspace-brand" aria-label="MyAaptha home"><Image src="/myaaptha-logo.png" width={38} height={38} alt="" priority /><strong>MyAaptha</strong></Link>
      <form className="workspace-global-search" onSubmit={search} role="search">
        <span aria-hidden="true">⌕</span><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Search people, circles and messages" aria-label="Search MyAaptha" />
        <button aria-label="Open search filters" type="submit">☷</button>
      </form>
      <nav className="workspace-top-actions" aria-label="Account tools"><Link href="/notifications" aria-label="Notifications">♢</Link><Link href="/privacy" aria-label="Settings">⚙</Link><Link href="/profile" className="workspace-account" aria-label="Profile">ME</Link></nav>
    </header>
    <aside className={`workspace-sidebar ${mobileOpen ? 'mobile-open' : ''}`} aria-label="Main navigation">
      <Link className="workspace-primary-action" href="/feed"><span>＋</span><b>New diary entry</b></Link>
      {navigationSections.map(section => <section className="workspace-nav-section" key={section.label}><h2>{section.label}</h2><nav>{section.items.map(item => <Link key={item.href} href={item.href as Route} title={item.label} className={isSelected(pathname, item.href) ? 'active' : ''}><span>{item.icon}</span><b>{item.label}</b></Link>)}</nav></section>)}
      <button type="button" className="workspace-sidebar-sign-out" disabled={signingOut} onClick={()=>void signOut()}><span>↪</span><b>{signingOut?'Signing out...':'Sign out'}</b></button>
    </aside>
    {mobileOpen && <button className="workspace-scrim" onClick={() => setMobileOpen(false)} aria-label="Close navigation" />}
    <div className="workspace-content">{children}</div>
    <aside className="workspace-utilities" aria-label="Quick tools">{utilities.map(item => <Link key={item.label} href={item.href as Route} title={item.label} aria-label={item.label}><span>{item.icon}</span></Link>)}</aside>
  </div>;
}
