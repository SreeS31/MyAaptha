'use client';
import InfoTip from '../components/InfoTip';
import UploadSettings from './UploadSettings';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApplicationSettings, NotificationPreferences, fetchApplicationSettings, updateApplicationSettings,
  fetchNotificationPreferences, updateNotificationPreferences, isUnauthorizedError } from '../lib/api';
import styles from './settings.module.css';

const categories: Array<[keyof NotificationPreferences,string]> = [['messagesEnabled','Private messages'],['circlesEnabled','Circle activity'],['relationshipsEnabled','Relationship updates'],['callsEnabled','Calls'],['invitationsEnabled','Invitations'],['socialEnabled','Likes and comments']];
const channels: Array<[keyof NotificationPreferences,string]> = [['pushEnabled','Push notifications'],['emailEnabled','Email'],['smsEnabled','SMS']];

export default function SettingsPage() {
  const router=useRouter();
  const [settings,setSettings]=useState<ApplicationSettings>();const [notifications,setNotifications]=useState<NotificationPreferences>();
  const [busy,setBusy]=useState(false);const [error,setError]=useState('');const [status,setStatus]=useState('');
  useEffect(()=>{let active=true;Promise.all([fetchApplicationSettings(),fetchNotificationPreferences()]).then(([s,n])=>{if(active){setSettings(s);setNotifications(n);}}).catch(e=>{if(isUnauthorizedError(e))router.replace('/auth');else if(active)setError(e.message);});return()=>{active=false;};},[router]);
  const change=<K extends keyof ApplicationSettings>(key:K,value:ApplicationSettings[K])=>{setSettings(s=>s?{...s,[key]:value}:s);setStatus('Unsaved changes');};
  const save=async()=>{if(!settings||!notifications)return;setBusy(true);setError('');setStatus('');
    try{setSettings(await updateApplicationSettings(settings));setNotifications(await updateNotificationPreferences(notifications));setStatus('Settings saved. These preferences follow your account on web and mobile.');}
    catch(e){setError(`Some settings may not have saved. ${(e as Error).message} Review and save again.`);}finally{setBusy(false);}};
  const setting=(key:'discoverable'|'shareConnections'|'shareInterests'|'intelligentSearch'|'compactLayout'|'reducedMotion'|'quietHoursEnabled'|'notificationPreviews',title:string,detail:string)=><div className={styles.option} key={key}><span><label htmlFor={`setting-${key}`}><strong>{title}</strong></label></span><InfoTip label={`About ${title.toLowerCase()}`}>{detail}</InfoTip><input id={`setting-${key}`} aria-label={title} type="checkbox" checked={settings?.[key]??false} onChange={e=>change(key,e.target.checked)} disabled={busy}/></div>;
  return <main className={`container ${styles.page}`}>
    <header className={styles.header}><div><p className="eyebrow">MAKE IT YOURS</p><div className="inline-help-heading"><h1>Personal settings</h1><InfoTip label="About Personal settings">Choose how you connect, what reaches you, and how your workspace feels.</InfoTip></div></div><Link className="btn btn-secondary" href="/profile">Edit profile</Link></header>
    {error&&<p className="error-message" role="alert">{error}</p>}
    {!settings||!notifications?<p role="status">Loading your preferences…</p>:<>
      <nav className={styles.sections} aria-label="Settings sections"><a href="#discovery">Discovery & privacy</a><a href="#notifications">Notifications</a><a href="#workspace">Workspace</a><a href="#account">Account controls</a></nav>
      <div className={styles.grid}><UploadSettings/>
        <section className={styles.card} id="discovery"><p className="eyebrow">CONNECT ON YOUR TERMS</p><div className="inline-help-heading"><h2>Discovery & privacy</h2><InfoTip label="About Discovery & privacy">Your private contact details are not included in search results.</InfoTip></div>
          {setting('discoverable','Let people find my profile','Appear in people search by name or location. Existing contacts can still see their saved connection.')}
          {setting('shareConnections','Show shared connections','Use your explicitly public relationship links to explain mutual connections. Everyone in a suggested link must allow this.')}
          {setting('shareInterests','Share interests and workplace for matching','Use the hobbies and employer in your profile to help people find common ground.')}
          {setting('intelligentSearch','Intelligent search ordering','Prioritize visible shared connections and interests. Name ranking uses the MyAaptha AI service when AI is enabled.')}
          <Link href="/ai-activity">Manage AI permissions and history →</Link>
        </section>
        <section className={styles.card} id="notifications"><p className="eyebrow">LESS NOISE, MORE CHOICE</p><h2>Notifications</h2><Link className="btn btn-secondary" href="/notifications">View notifications</Link><InfoTip label="About this feature">Choose activity types and delivery channels. Delivery also depends on device permissions and enabled channels.</InfoTip>
          <fieldset><legend>Notify me about</legend><div className={styles.checks}>{categories.map(([key,label])=><label key={key}><input type="checkbox" disabled={busy} checked={notifications[key]} onChange={e=>{setNotifications({...notifications,[key]:e.target.checked});setStatus('Unsaved changes');}}/>{label}</label>)}</div></fieldset>
          <fieldset><legend>Send updates through</legend><div className={styles.checks}>{channels.map(([key,label])=><label key={key}><input type="checkbox" disabled={busy} checked={notifications[key]} onChange={e=>{setNotifications({...notifications,[key]:e.target.checked});setStatus('Unsaved changes');}}/>{label}</label>)}</div></fieldset>
          {setting('notificationPreviews','Show message previews','Include names and update details in external notifications. Turn off for more privacy on shared devices.')}
          {setting('quietHoursEnabled','Quiet hours','Delay external notifications during this time. Your in-app inbox remains available.')}
          <div className={styles.times}><label>From<input type="time" disabled={busy||!settings.quietHoursEnabled} value={settings.quietStart} onChange={e=>change('quietStart',e.target.value)}/></label><label>Until<input type="time" disabled={busy||!settings.quietHoursEnabled} value={settings.quietEnd} onChange={e=>change('quietEnd',e.target.value)}/></label></div>
          <label className={styles.zone}>Time zone<input value={settings.timeZone} maxLength={80} onChange={e=>change('timeZone',e.target.value)} disabled={busy} placeholder="Asia/Kolkata"/></label><button type="button" className="btn btn-secondary" disabled={busy} onClick={()=>change('timeZone',Intl.DateTimeFormat().resolvedOptions().timeZone)}>Use this device’s time zone</button>
        </section>
        <section className={styles.card} id="workspace"><p className="eyebrow">A COMFORTABLE WORKSPACE</p><h2>Layout & accessibility</h2>{setting('compactLayout','Compact spacing','Fit more into the workspace with tighter spacing.')}{setting('reducedMotion','Reduce motion','Minimize transitions and smooth scrolling.')}
          <InfoTip label="About this feature">The previous family tree and the expandable chain explorer both remain available on your dashboard.</InfoTip><Link href="/dashboard">Open your network →</Link>
        </section>
        <section className={styles.card} id="account"><p className="eyebrow">YOU STAY IN CONTROL</p><h2>Account controls</h2><div className={styles.links}><Link href="/privacy">Privacy, blocked accounts & data controls <span>→</span></Link><Link href="/session">Account session <span>→</span></Link><Link href="/ai-activity">AI permissions & activity <span>→</span></Link><Link href="/notifications">Notification inbox <span>→</span></Link><Link href="/reports">Your safety reports <span>→</span></Link></div></section>
      </div><footer className={styles.save}><span className="inline-help-heading"><span role="status">{status||'Account preferences'}</span><InfoTip label="About saving settings">Your choices apply to your account across web and mobile. Select Save settings to keep your changes.</InfoTip></span><button className="btn btn-primary" disabled={busy} onClick={()=>void save()}>{busy?'Saving…':'Save settings'}</button></footer>
    </>}
  </main>;
}
