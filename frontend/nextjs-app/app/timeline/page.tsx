'use client';
import Link from 'next/link';
import LifeTimeline from '../components/LifeTimeline';
export default function TimelinePage(){return <main className="container timeline-page"><header className="profile-header"><div><p className="eyebrow">MY MYAAPTHA TIMELINE</p><h1>My timeline</h1><p>A chronological view of the milestones that shape your life.</p></div><Link className="btn btn-secondary" href="/profile">Edit profile details</Link></header><LifeTimeline/></main>;}
