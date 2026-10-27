 'use client';
import {useState} from 'react';
import type {NetworkRelationship,NetworkCircle} from '../lib/api';
import InsightBars from './InsightBars';
export default function NetworkInsights({relationships,circles}:{relationships:NetworkRelationship[];circles:NetworkCircle[]}) {
 const [view,setView]=useState<'relationships'|'circles'>('relationships');
 const counts=relationships.reduce<Record<string,number>>((result,item)=>{const label=item.type||'Other';result[label]=(result[label]||0)+1;return result;},{});
 const items=view==='relationships'?Object.entries(counts).map(([label,value])=>({label,value})):circles.map(circle=>({label:circle.name,value:circle.members.length}));
 items.sort((a,b)=>b.value-a.value||a.label.localeCompare(b.label));
 return <section className="network-insights card"><div className="insight-heading"><div><p className="eyebrow">YOUR CONNECTIONS</p><h2>Your network at a glance</h2></div><div className="insight-switch" role="group" aria-label="Network chart"><button aria-pressed={view==='relationships'} onClick={()=>setView('relationships')}>Relationships</button><button aria-pressed={view==='circles'} onClick={()=>setView('circles')}>Circles</button></div></div><InsightBars title={view==='relationships'?'Relationships by type':'People in each circle'} description={view==='relationships'?'Counts from your saved relationships.':'Member counts for your circles. A person can belong to more than one circle.'} items={items}/></section>;
}
