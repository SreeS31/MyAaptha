'use client';

import PageHeading from '../components/PageHeading';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';

import { fetchAuthHealth, fetchSessionProfile, getSessionTiming, hasAuthSession, logout, refreshSession, revokeSession } from '../lib/api';

export default function SessionPage() {
  const router = useRouter();
  const [authHealth, setAuthHealth] = useState('checking...');
  const [profile, setProfile] = useState<{ username: string; email: string } | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState(0);
  const [expiresAtLabel, setExpiresAtLabel] = useState('-');
  const [issuedAtLabel, setIssuedAtLabel] = useState('-');
  const [status, setStatus] = useState('Loading session state...');
  const [busyAction, setBusyAction] = useState<'refresh' | 'revoke' | 'logout' | null>(null);

  const updateTimingState = useCallback(() => {
    const timing = getSessionTiming();
    if (!timing) {
      setSecondsRemaining(0);
      setExpiresAtLabel('-');
      setIssuedAtLabel('-');
      return;
    }

    setSecondsRemaining(timing.secondsRemaining);
    setIssuedAtLabel(new Date(timing.receivedAtEpochMs).toLocaleString());
    setExpiresAtLabel(new Date(timing.expiresAtEpochMs).toLocaleString());
  }, []);

  const loadSessionDetails = useCallback(async () => {
    if (!hasAuthSession()) {
      router.replace('/auth');
      return;
    }

    try {
      const [health, sessionProfile] = await Promise.all([
        fetchAuthHealth(),
        fetchSessionProfile(),
      ]);
      setAuthHealth(health);
      setProfile({ username: sessionProfile.username, email: sessionProfile.email });
      setStatus('Session state is active and healthy.');
      updateTimingState();
    } catch {
      setStatus('Session could not be validated. Please sign in again.');
      router.replace('/auth?reason=session-expired');
    }
  }, [router, updateTimingState]);

  useEffect(() => {
    loadSessionDetails();

    const intervalId = window.setInterval(() => {
      updateTimingState();
    }, 1000);

    return () => {
      window.clearInterval(intervalId);
    };
  }, [loadSessionDetails, updateTimingState]);

  const handleRefresh = async () => {
    setBusyAction('refresh');
    setStatus('Refreshing session token...');

    try {
      await refreshSession();
      await loadSessionDetails();
      setStatus('Session refreshed successfully.');
    } catch {
      setStatus('Refresh failed. Please sign in again.');
      router.replace('/auth?reason=session-expired');
    } finally {
      setBusyAction(null);
    }
  };

  const handleRevoke = async () => {
    setBusyAction('revoke');
    setStatus('Revoking session token...');

    try {
      await revokeSession();
      setStatus('Session revoked. Redirecting to sign in...');
      router.replace('/auth');
    } catch {
      setStatus('Revoke failed. Please sign in again.');
      router.replace('/auth?reason=session-expired');
    } finally {
      setBusyAction(null);
    }
  };

  const handleLogout = async () => {
    setBusyAction('logout');
    setStatus('Signing out...');

    try {
      await logout();
      router.replace('/auth');
    } finally {
      setBusyAction(null);
    }
  };

  return (
    <main className="container session-shell">
      <PageHeading title="Account session" help="Check your signed-in account, refresh your session, or sign out." />
      <section className="card session-hero">
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', marginTop: '1rem' }}>
          <div className="card session-stat" style={{ padding: '1rem' }}>
            <h3 style={{ marginTop: 0 }}>Signed-in account</h3>
            <p style={{ marginBottom: '0.35rem' }}><strong>User:</strong> {profile?.username || '-'}</p>
            <p style={{ marginBottom: 0 }}><strong>Email:</strong> {profile?.email || '-'}</p>
          </div>
          <div className="card session-stat" style={{ padding: '1rem' }}>
            <h3 style={{ marginTop: 0 }}>Session timing</h3>
            <p style={{ marginBottom: '0.35rem' }}><strong>Issued:</strong> {issuedAtLabel}</p>
            <p style={{ marginBottom: '0.35rem' }}><strong>Expires:</strong> {expiresAtLabel}</p>
            <p style={{ marginBottom: 0 }}><strong>Seconds Remaining:</strong> {secondsRemaining}</p>
          </div>
          <div className="card session-stat" style={{ padding: '1rem' }}>
            <h3 style={{ marginTop: 0 }}>Connection status</h3>
            <p style={{ marginBottom: 0 }}><strong>Auth API:</strong> {authHealth}</p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', marginTop: '1rem' }}>
          <button type="button" className="btn btn-primary" onClick={handleRefresh} disabled={busyAction !== null}>
            {busyAction === 'refresh' ? 'Refreshing...' : 'Refresh Session'}
          </button>
          <button type="button" className="btn btn-secondary" onClick={handleRevoke} disabled={busyAction !== null}>
            {busyAction === 'revoke' ? 'Revoking...' : 'Revoke Session'}
          </button>
          <button type="button" className="btn" onClick={handleLogout} disabled={busyAction !== null}>
            {busyAction === 'logout' ? 'Signing out...' : 'Sign Out'}
          </button>
        </div>

        <p style={{ marginTop: '1rem', color: '#2563eb' }}>{status}</p>
      </section>
    </main>
  );
}
