'use client';
import {displayCopy} from '../lib/display-copy';
import InfoTip from '../components/InfoTip';


import {useCallback,useEffect,useState} from 'react';
import {useRouter} from 'next/navigation';
import {AbuseReport,fetchMyReports,hasAuthSession,isUnauthorizedError} from '../lib/api';

export default function MyReportsPage(){const router=useRouter();const [reports,setReports]=useState<AbuseReport[]>([]);const [error,setError]=useState('');const load=useCallback(async()=>{try{setReports(await fetchMyReports());setError('');}catch(caught){if(isUnauthorizedError(caught))router.replace('/auth');else setError((caught as Error).message);}},[router]);useEffect(()=>{if(!hasAuthSession())router.replace('/auth');else void load();},[load,router]);return <main className="container moderation-page"><header className="network-header"><div><div className="inline-help-heading"><h1>My reports</h1><InfoTip label="About My reports">Track the review status of content and accounts you reported.</InfoTip></div></div></header>{error&&<p className="network-message error-message">{error}</p>}<section className="moderation-list">{reports.map(report=><article className="card" key={report.id}><header><span className={`moderation-status status-${report.status.toLowerCase()}`}>{report.status}</span><time>{new Date(report.createdAt).toLocaleString()}</time></header><h2>{report.reason.replaceAll('_',' ')}</h2><p>{report.details||'No additional details supplied.'}</p><dl><div><dt>Report</dt><dd>#{report.id}</dd></div><div><dt>Reported item</dt><dd>{report.entityType||'Account'} {report.entityId?`#${report.entityId}`:''}</dd></div></dl>{report.moderatorNotes&&<blockquote><strong>Moderator response:</strong> {report.moderatorNotes}</blockquote>}</article>)}{!reports.length&&!error&&<p className="card social-empty">{displayCopy.noReports}</p>}</section></main>}
