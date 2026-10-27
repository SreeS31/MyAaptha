'use client';
import {Suspense,useEffect,useState} from 'react';
import {useRouter} from 'next/navigation';
import {fetchSessionProfile,isUnauthorizedError} from '../lib/api';
import UserNetworkDashboard from '../dashboard/UserNetworkDashboard';

function RelationshipTree(){
  const router=useRouter();
  const [username,setUsername]=useState<string|null>(null),[error,setError]=useState('');
  useEffect(()=>{let active=true;fetchSessionProfile().then(profile=>{if(active)setUsername(profile.username);}).catch(e=>{if(!active)return;if(isUnauthorizedError(e))router.replace('/auth');else setError(e.message);});return()=>{active=false;};},[router]);
  if(error)return <main className="container"><p role="alert">{error}</p></main>;
  if(username===null)return <main className="container"><p role="status">Loading your relationship tree…</p></main>;
  return <UserNetworkDashboard username={username} treeOnly/>;
}
export default function RelationshipTreePage(){return <Suspense fallback={<main className="container">Loading your relationship tree…</main>}><RelationshipTree/></Suspense>;}
