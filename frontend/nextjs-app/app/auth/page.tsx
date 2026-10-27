'use client';

import Link from 'next/link';
import {securityPolicy} from '../lib/api';
import Image from 'next/image';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useState } from 'react';

import { ApiError, createUser, hasAuthSession, login } from '../lib/api';
import CountryPhoneInput from '../components/CountryPhoneInput';

function AuthForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [ready,setReady]=useState(false);
  useEffect(()=>setReady(true),[]);
  const [otpCode,setOtpCode]=useState('');
  const [verificationCode,setVerificationCode]=useState('');
  const [verificationRequired,setVerificationRequired]=useState(true);
  useEffect(()=>{void securityPolicy().then(value=>setVerificationRequired(value.phoneVerificationRequired)).catch(()=>{});},[]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [status, setStatus] = useState('Sign in with your MyAaptha account.');
  const [mode, setMode] = useState<'signin' | 'register'>('signin');
  const [profile, setProfile] = useState({ username: '', firstName: '', surname: '', phoneNumber: '', email: '', location: '' });

  useEffect(() => {
    if (hasAuthSession()) {
      router.replace('/dashboard');
      return;
    }

    const reason = searchParams.get('reason');
    if (reason === 'session-expired') {
      setStatus('Your session expired. Please sign in again.');
    }
  }, [router, searchParams]);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsSubmitting(true);
    setStatus('Signing you in...');

    try {
      await login(identifier.trim(), password,otpCode);
      setStatus('Signed in. Redirecting to dashboard...');
      router.replace('/dashboard');
    } catch (error) {
      if (error instanceof ApiError && error.status === 429) {
        setStatus('Too many sign-in attempts. Please wait a minute and try again.');
      } else if (!(error instanceof ApiError) || error.status === 0 || error.status >= 500) {
        setStatus('The sign-in service is unavailable or took too long to respond. Please try again shortly.');
      } else if (error instanceof ApiError && error.status === 400) {
        setStatus(error.message);
      } else {
        setStatus('Sign-in failed. Check your account identifier, password and authenticator code if required.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRegistration = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsSubmitting(true);
    setStatus('Creating your account...');
    try {
      await createUser({ ...profile, email: profile.email || undefined, password,verificationCode });
      await login(profile.phoneNumber, password);
      setStatus('Account created. Opening your network...');
      router.replace('/dashboard');
    } catch (error) {
      setStatus(error instanceof ApiError ? error.message : 'Account creation failed. Please check your details.');
    } finally { setIsSubmitting(false); }
  };

  return (
    <main className="auth-shell">
      <section className="auth-story">
        <Image className="auth-logo" src="/myaaptha-logo-256.webp" unoptimized width={112} height={112} alt="MyAaptha logo" priority />
        <p className="eyebrow">YOUR PEOPLE & MEMORIES</p>
        <h1>Stay close to the people who matter.</h1>
        <p>Build your relationship tree, share with your circles, and keep a diary with an audience you choose.</p>
        <div className="auth-pills"><span>Relationships</span><span>Private memories</span><span>Conversations</span></div>
      </section>
      <section className="auth-panel">
      <div className="card auth-card">
        <p className="eyebrow">{mode === 'signin' ? 'WELCOME BACK' : 'JOIN MYAAPTHA'}</p>
        <h2>{mode === 'signin' ? 'Sign in to your workspace' : 'Create your account'}</h2>
        <p style={{ color: 'var(--text-muted)', marginBottom: '1.5rem' }}>{mode === 'signin' ? 'Use your credentials to continue.' : 'Your unique mobile number keeps duplicate accounts out.'}</p>

        {mode === 'signin' ? <form aria-busy={!ready||isSubmitting} onSubmit={handleSubmit} style={{ display: 'grid', gap: '1rem' }}>
          <fieldset disabled={!ready||isSubmitting} style={{display:'contents'}}>
          <label style={{ display: 'grid', gap: '0.4rem' }}>
            <span>Username or mobile number</span>
            <input
              type="text"
              autoComplete="username"
              required
              value={identifier}
              onChange={(event) => setIdentifier(event.target.value)}
              placeholder="Username or mobile number"
              style={{ padding: '0.8rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
            />
          </label>
          <label style={{ display: 'grid', gap: '0.4rem' }}>
            <span>Password</span>
            <input
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Enter your password"
              style={{ padding: '0.8rem', borderRadius: '0.75rem', border: '1px solid #dbe3ee' }}
            />
          </label>
          <label><span>Authenticator code (administrators)</span><input inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={otpCode} onChange={e=>setOtpCode(e.target.value)}/></label>
          <Link href="/recover-account">Forgot password or need to verify your account?</Link>
          <button className="btn btn-primary" type="submit" disabled={isSubmitting}>
            {isSubmitting ? 'Signing in...' : 'Continue'}
          </button>
          </fieldset>
        </form> : <form aria-busy={!ready||isSubmitting} onSubmit={handleRegistration} className="registration-form">
          <fieldset disabled={!ready||isSubmitting} style={{display:'contents'}}>
          <div className="registration-row"><label><span>First name</span><input required value={profile.firstName} onChange={e => setProfile({...profile, firstName:e.target.value})} /></label><label><span>Surname</span><input required value={profile.surname} onChange={e => setProfile({...profile, surname:e.target.value})} /></label></div>
          <label><span>Username</span><input required value={profile.username} onChange={e => setProfile({...profile, username:e.target.value})} /></label>
          <label><span>Mobile number</span><CountryPhoneInput required value={profile.phoneNumber} onChange={phoneNumber => setProfile({...profile, phoneNumber})}/></label>
          {verificationRequired&&<div><Link href="/verify-phone" target="_blank" rel="noopener noreferrer">Request a verification code</Link><label><span>SMS verification code</span><input required inputMode="numeric" autoComplete="one-time-code" value={verificationCode} onChange={e=>setVerificationCode(e.target.value)} maxLength={10}/></label></div>}
          <label><span>Email (optional)</span><input type="email" value={profile.email} onChange={e => setProfile({...profile, email:e.target.value})} /></label>
          <label><span>Location</span><input required value={profile.location} onChange={e => setProfile({...profile, location:e.target.value})} placeholder="Bengaluru" /></label>
          <label><span>Password</span><input type="password" autoComplete="new-password" required minLength={8} value={password} onChange={e => setPassword(e.target.value)} /></label>
          <button className="btn btn-primary" disabled={isSubmitting}>{isSubmitting ? 'Creating account...' : 'Create account'}</button>
          </fieldset>
        </form>}

        <p role="status" aria-live="polite" className="status-note" style={{ marginTop: '1rem' }}>{status}</p>
        <button type="button" className="text-button auth-switch" onClick={() => { setMode(mode === 'signin' ? 'register' : 'signin'); setStatus(mode === 'signin' ? 'Create a searchable profile using your unique mobile number.' : 'Sign in with your MyAaptha account.'); }}>{mode === 'signin' ? 'New to MyAaptha? Create an account' : 'Already have an account? Sign in'}</button>
        <p style={{ marginTop: '1rem' }}>
          <Link href="/">Back to home</Link>
        </p>
      </div>
      </section>
    </main>
  );
}

export default function AuthPage() {
  return (
    <Suspense fallback={<main className="container" style={{ paddingTop: '3rem' }}>Loading sign-in…</main>}>
      <AuthForm />
    </Suspense>
  );
}
