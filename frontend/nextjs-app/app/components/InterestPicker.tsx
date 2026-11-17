'use client';
import {useId,useState} from 'react';
import {allInterests,interestCategories} from '../lib/interests-catalog';
export default function InterestPicker({value,onChange}:{value:string[];onChange:(value:string[])=>void}) {
 const id=useId();const [query,setQuery]=useState('');const [category,setCategory]=useState('');
 const options=(category?interestCategories[category]:allInterests).filter(v=>v.toLowerCase().includes(query.toLowerCase()));
 const selected=(option:string)=>value.some(v=>v.toLowerCase()===option.toLowerCase());
 function toggle(option:string){onChange(selected(option)?value.filter(v=>v.toLowerCase()!==option.toLowerCase()):[...value,option]);}
 return <div className="interest-picker"><div className="interest-filters"><label htmlFor={`${id}-search`}>Find a hobby or interest<input id={`${id}-search`} value={query} maxLength={120} placeholder="Search cycling, startups, music…" onChange={e=>setQuery(e.target.value)}/></label><label htmlFor={`${id}-category`}>Category<select id={`${id}-category`} value={category} onChange={e=>setCategory(e.target.value)}><option value="">All categories</option>{Object.keys(interestCategories).map(c=><option key={c}>{c}</option>)}</select></label></div>
 <label htmlFor={`${id}-add`}>Add from available interests<select id={`${id}-add`} value="" onChange={e=>{if(e.target.value&&!selected(e.target.value))onChange([...value,e.target.value]);}}><option value="">Choose an interest…</option>{options.map(v=><option key={v} value={v} disabled={selected(v)}>{v}{selected(v)?' — selected':''}</option>)}</select></label>
 <div className="interest-options" role="group" aria-label="Available interests">{options.map(option=><label key={option}><input type="checkbox" checked={selected(option)} onChange={()=>toggle(option)}/>{option}</label>)}</div>
 {query.trim()&&!allInterests.some(v=>v.toLowerCase()===query.trim().toLowerCase())&&!selected(query.trim())&&<button type="button" className="btn btn-secondary" disabled={query.includes(',')} onClick={()=>{onChange([...value,query.trim()]);setQuery('');}}>Add “{query.trim()}”</button>}
 <p>{value.length} selected. Choose as many as you like.</p><div className="interest-tags">{value.map(v=><button type="button" className="interest-tag" aria-label={`Remove ${v}`} key={v} onClick={()=>toggle(v)}>{v} ×</button>)}</div></div>;
}
