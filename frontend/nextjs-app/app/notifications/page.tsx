'use client';
import InfoTip from '../components/InfoTip';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  AppNotification,
  fetchNotificationPreferences,
  fetchNotifications,
  hasAuthSession,
  isUnauthorizedError,
  markAllNotificationsRead,
  markNotificationRead,
  NotificationPreferences,
  updateNotificationPreferences,
} from '../lib/api';

const preferenceLabels: Array<[keyof NotificationPreferences, string]> = [
  ['messagesEnabled', 'Direct messages'], ['circlesEnabled', 'Circle messages'],
  ['socialEnabled', 'Likes and comments'], ['relationshipsEnabled', 'Relationships'],
  ['callsEnabled', 'Calls'], ['invitationsEnabled', 'Invitations'],
];
const channelLabels: Array<[keyof NotificationPreferences, string]> = [
  ['pushEnabled', 'Push'], ['emailEnabled', 'Email'], ['smsEnabled', 'SMS'],
];

export default function NotificationsPage() {
  const router = useRouter();
  const [items, setItems] = useState<AppNotification[]>([]);
  const [preferences, setPreferences] = useState<NotificationPreferences>();
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const load = useCallback(async () => {
    try {
      const [notificationData, preferenceData] = await Promise.all([fetchNotifications(), fetchNotificationPreferences()]);
      setItems(notificationData); setPreferences(preferenceData);
    } catch (caught) {
      if (isUnauthorizedError(caught)) router.replace('/auth'); else setError((caught as Error).message);
    }
  }, [router]);
  useEffect(() => { if (!hasAuthSession()) router.replace('/auth'); else void load(); }, [load, router]);
  const open = async (item: AppNotification) => { if (!item.readAt) await markNotificationRead(item.id); if (item.actionUrl) router.push(item.actionUrl as Parameters<typeof router.push>[0]); else await load(); };
  const toggle = (key: keyof NotificationPreferences) => setPreferences(current => current ? { ...current, [key]: !current[key] } : current);
  const save = async () => { if (!preferences) return; setSaving(true); setError(''); try { setPreferences(await updateNotificationPreferences(preferences)); } catch (caught) { setError((caught as Error).message); } finally { setSaving(false); } };
  return <main className="container notifications-page">
    <header className="network-header"><div><p className="eyebrow">STAY UPDATED</p><div className="inline-help-heading"><h1>Notifications</h1><InfoTip label="About Notifications">Messages, calls, social activity, circles, and relationship updates.</InfoTip></div></div><div className="network-actions"><button className="btn btn-secondary" onClick={async () => { await markAllNotificationsRead(); await load(); }}>Mark all read</button><Link href="/dashboard" className="btn btn-secondary">Dashboard</Link></div></header>
    {error && <p className="network-message error-message">{error}</p>}
    {preferences && <section className="card notification-preferences"><div><h2>Notification preferences</h2><p>Choose the activity and delivery channels you want.</p></div><fieldset><legend>Notify me about</legend>{preferenceLabels.map(([key, label]) => <label key={key}><input type="checkbox" checked={preferences[key]} onChange={() => toggle(key)} />{label}</label>)}</fieldset><fieldset><legend>Delivery channels</legend>{channelLabels.map(([key, label]) => <label key={key}><input type="checkbox" checked={preferences[key]} onChange={() => toggle(key)} />{label}</label>)}</fieldset><button className="btn btn-primary" disabled={saving} onClick={() => void save()}>{saving ? 'Saving…' : 'Save preferences'}</button></section>}
    <section className="notification-list">{items.map(item => <button key={item.id} className={`card notification-item ${item.readAt ? '' : 'unread'}`} onClick={() => void open(item)}><span className="notification-icon">{item.type === 'DIRECT_MESSAGE' ? '✉' : item.type === 'CALL' ? '☎' : item.type.startsWith('SOCIAL') ? '♥' : '●'}</span><span><strong>{item.title}</strong><small>{item.body}</small><time>{new Date(item.createdAt).toLocaleString()}</time></span>{!item.readAt && <i />}</button>)}{!items.length && <div className="card social-empty"><h2>You are all caught up</h2><p>New activity will appear here.</p></div>}</section>
  </main>;
}
