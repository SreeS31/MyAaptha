'use client';
import PageHeading from '../components/PageHeading';

import LifeTimeline from '../components/LifeTimeline';
export default function TimelinePage(){return <main className="container timeline-page"><PageHeading title="My timeline" help="Latest milestones first. Add or edit events here; profile and relationship details stay separate."/><LifeTimeline/></main>;}
