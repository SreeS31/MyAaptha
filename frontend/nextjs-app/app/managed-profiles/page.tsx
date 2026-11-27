 'use client';
import Link from 'next/link';
import {useEffect,useState} from 'react';
import {fetchMyRelationships,type NetworkRelationship} from '../lib/api';
export default function ManagedProfiles(){
 const [rows,setRows]=useState<NetworkRelationship[]>([]),[error,setError]=useState(''),[loading,setLoading]=useState(true);
 useEffect(()=>{let active=true;fetchMyRelationships().then(value=>{if(active)setRows(value.filter(item=>item.person.identityType==='MANAGED'||item.person.accountStatus==='MANAGED'));}).catch(e=>{if(active)setError((e as Error).message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[]);
 return <main className="container"><header className="network-header"><h1>Managed profiles</h1><Link href="/relationship-tree" className="btn btn-secondary">Add a person</Link></header>{loading?<p role="status">Loading profiles...</p>:error?<p role="alert">{error}</p>:!rows.length?<p>No managed profiles yet.</p>:<ul className="managed-profile-list">{rows.map(row=><li key={row.id}><Link href={`/people/${row.person.id}`}>{row.person.displayName}</Link><small>{row.type}</small></li>)}</ul>}</main>;
}
