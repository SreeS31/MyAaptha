'use client';
import InfoTip from '../components/InfoTip';

import Link from 'next/link';
import type { Route } from 'next';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { fetchHelpStatus, askHelp, HelpReply, setHelpEnhanced, clearHelpHistory, clearSharedHelp, publishHelpAnswer } from '../lib/api';
import styles from './page.module.css';

type Message = { role: 'user' | 'assistant'; content: string; question?:string; reply?: HelpReply };
export default function HelpPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [question, setQuestion] = useState('');
  const [enhanced, setEnhanced] = useState(false);
  const [admin, setAdmin] = useState(false);
  const [review, setReview] = useState<{question:string;answer:string;sourceIds:string[]}|null>(null);
  const [confirmed, setConfirmed] = useState(false);
  const [configured, setConfigured] = useState(false);
  const [useAi, setUseAi] = useState(false);
  const [questions, setQuestions] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const end = useRef<HTMLDivElement>(null);
  useEffect(()=>{try{const draft=sessionStorage.getItem('myaaptha-help-draft');if(draft){sessionStorage.removeItem('myaaptha-help-draft');setQuestion(draft.slice(0,1200));}}catch{}},[]);
  useEffect(() => { let active = true;
    fetchHelpStatus().then(value => { if (active) { setConfigured(value.aiConfigured); setEnhanced(value.enhancedEnabled); setAdmin(value.canManage); setQuestions(value.questions); } })
      .catch(() => { if (active) setError('Sign in to use MyAaptha help, or try again if the service is unavailable.'); });
    return () => { active = false; };
  }, []);
  useEffect(() => { end.current?.scrollIntoView({ block: 'nearest' }); }, [messages, busy]);
  async function send(event: FormEvent) {
    event.preventDefault();
    const text = question.trim(); if (!text || busy) return;
    const history = messages.slice(-4).map(({ role, content }) => ({ role, content: content.slice(0, 2500) }));
    setBusy(true); setError(''); setQuestion('');
    setMessages(current => [...current.slice(-19), { role: 'user', content: text }]);
    try {
      const reply = await askHelp(text, history, useAi);
      setMessages(current => [...current, { role: 'assistant', content: reply.answer, question:text, reply }]);
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Help is unavailable. Please try again.'); setQuestion(text);
    } finally { setBusy(false); }
  }
  async function retry(reply:HelpReply, originalQuestion:string) {
    if(busy || !reply.exchangeId)return;
    setBusy(true);setError('');
    try {
      const result=await askHelp('Retry my saved question',[],true,reply.exchangeId);
      setMessages(current=>[...current,{role:'assistant',content:result.answer,question:originalQuestion,reply:result}]);
    } catch(failure){setError(failure instanceof Error?failure.message:'Retry failed');}
    finally{setBusy(false);}
  }
  async function clear(){
    setBusy(true);setError('');
    try{await clearHelpHistory();setMessages([]);}catch{setError('Could not delete saved chat. Please try again.');}
    finally{setBusy(false);}
  }
  async function changeEnhanced(enabled:boolean){
    setBusy(true);setError('');
    try{await setHelpEnhanced(enabled);setEnhanced(enabled);}catch{setError('Could not update administrator settings.');}
    finally{setBusy(false);}
  }
  async function publish(event:FormEvent){
    event.preventDefault();if(!review||!confirmed)return;
    setBusy(true);setError('');
    try{await publishHelpAnswer(review.question,review.answer,review.sourceIds);setReview(null);setConfirmed(false);}
    catch{setError('Could not publish the reviewed answer.');}finally{setBusy(false);}
  }
  return <main className={styles.page}>
    <header className={styles.heading}><div><p className="eyebrow">MYAAPTHA HELP</p><h1>Ask MyAaptha</h1><p>Practical answers from your application’s help guide.</p></div>
      <button className="btn btn-secondary" disabled={busy} onClick={clear}>Clear chat</button></header>
    <section className={styles.options} aria-label="Answer settings">
      <label><input type="checkbox" checked={useAi} disabled={!configured || busy} onChange={event => setUseAi(event.target.checked)} /> Use OpenAI answers</label>
      <div className="inline-help-copy">{configured ? 'Your question and recent conversation are sent to OpenAI when enabled.' : 'Application help is available. OpenAI answers need server configuration.'}<InfoTip label="Help and privacy"><p>Avoid passwords and private records. Questions and replies are saved privately for reuse, according to your AI controls retention setting. Clear chat also deletes your saved help history. Only administrator-reviewed general answers are shared across users.</p></InfoTip></div>
      
    </section>
    {admin && <details className={styles.options}><summary>Administrator: AI cost controls</summary>
      <label><input type="checkbox" checked={enhanced} disabled={busy} onChange={e=>changeEnhanced(e.target.checked)} /> Allow users to try a stronger model</label>
      <p>Off by default. Each retry requires a user click. Maximum two paid stronger retries per user per 24 hours. Stronger answers may still be incorrect.</p>
      <button disabled={busy} onClick={async()=>{setBusy(true);try{await clearSharedHelp();}catch{setError('Could not clear shared answers.');}finally{setBusy(false);}}}>Clear shared answer cache</button>
    </details>}
    <div className={styles.suggestions} aria-label="Suggested questions">{questions.map(item => <button key={item} disabled={busy} onClick={() => setQuestion(item)}>{item}</button>)}</div>
    <section className={styles.conversation} role="log" aria-live="polite" aria-label="Help conversation">
      {!messages.length && <p>Ask about free access, profile contacts, adding relations, or horizontal and vertical broadcasts.</p>}
      {messages.map((item, index) => <article key={index} className={item.role === 'user' ? styles.user : styles.assistant}>
        <strong>{item.role === 'user' ? 'You' : item.reply?.mode === 'CACHE' ? 'MyAaptha saved answer' : item.reply?.mode === 'AI' ? 'MyAaptha AI' : 'MyAaptha help'}</strong>
        <p className={styles.answer}>{item.content}</p>
        {item.reply?.notice && <p className={styles.notice}>{item.reply.notice}</p>}
        {item.reply?.model && item.reply.mode==='AI' && <small>{item.reply.model}</small>}
        {enhanced && configured && item.reply?.exchangeId && item.reply.tier==='BASE' && item.reply.mode!=='HELP' && <button disabled={busy} onClick={()=>retry(item.reply!,item.question||'')}>Not satisfied? Try stronger model</button>}
        {admin && item.reply && item.reply.sources.length>0 && <button disabled={busy} onClick={()=>{const q=item.question||'';setReview({question:q,answer:item.content,sourceIds:item.reply!.sources.map(s=>s.id)});setConfirmed(false);}}>Review for shared answers</button>}
        {!!item.reply?.sources.length && <nav aria-label="Answer sources"><strong>Sources</strong>{item.reply.sources.map(source => <details key={source.id}><summary>{source.title}</summary><p className={styles.answer}>{source.content}</p><Link href={source.path as Route}>Open in MyAaptha</Link></details>)}</nav>}
      </article>)}
      {busy && <p role="status">Finding an answer…</p>}<div ref={end} />
    </section>
    {review && <form onSubmit={publish} className={styles.options}>
      <h2>Review a public help answer</h2>
      <p>Remove names, contact details and account-specific information. Verify the answer against its sources. It will be reused for the same question for up to 30 days, or until the help guide changes.</p>
      <label>General question<input required maxLength={1200} value={review.question} onChange={e=>setReview({...review,question:e.target.value})}/></label>
      <label>Reviewed answer<textarea required rows={4} maxLength={5000} value={review.answer} onChange={e=>setReview({...review,answer:e.target.value})}/></label>
      <label><input type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/> I verified this answer is correct and contains no private information.</label>
      <button disabled={busy||!confirmed}>Publish shared answer</button><button type="button" onClick={()=>setReview(null)}>Cancel</button>
    </form>}
    {error && <p role="alert" className={styles.error}>{error}</p>}
    <form className={styles.composer} onSubmit={send}>
      <label htmlFor="help-question">Your question</label>
      <textarea id="help-question" value={question} onChange={event => setQuestion(event.target.value)} maxLength={1200} rows={3} required placeholder="How do I add a new relation?" disabled={busy} />
      <button className="btn btn-primary" disabled={busy || !question.trim()}>{busy ? 'Answering…' : 'Ask'}</button>
    </form>
    <p className={styles.notice}>This assistant explains features. It cannot view private records or perform actions. Verify important instructions using the sources.</p>
  </main>;
}
