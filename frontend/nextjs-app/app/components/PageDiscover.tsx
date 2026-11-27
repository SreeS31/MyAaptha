 'use client';
import {useEffect,useRef,useState} from 'react';
type Match={element:HTMLElement;text:string};
export default function PageDiscover({page}:{page:string}){
 const [query,setQuery]=useState(''),[matches,setMatches]=useState<Match[]>([]),[active,setActive]=useState(-1),[searched,setSearched]=useState(false);const input=useRef<HTMLInputElement>(null);
 useEffect(()=>{setQuery('');setMatches([]);setActive(-1);setSearched(false);document.querySelectorAll('.page-discover-match').forEach(el=>el.classList.remove('page-discover-match'));},[page]);
 function search(){const root=document.getElementById('workspace-main'),term=query.trim().toLocaleLowerCase();document.querySelectorAll('.page-discover-match').forEach(el=>el.classList.remove('page-discover-match'));setActive(-1);setSearched(!!term);if(!root||!term){setMatches([]);return;}
 const found:Match[]=[];const seen=new Set<string>();root.querySelectorAll<HTMLElement>('h1,h2,h3,h4,h5,h6,p,dt,dd,li,button,a,td,th,label,summary').forEach(element=>{
 if(element.closest('[aria-hidden="true"],[hidden],script,style')||element.querySelector('h1,h2,h3,p,li,button,a,td,th,summary'))return;
 const text=(element.textContent||'').replace(/\s+/g,' ').trim();if(!text.toLocaleLowerCase().includes(term)||!element.getClientRects().length)return;
 const key=text.toLocaleLowerCase();if(!seen.has(key)){found.push({element,text});seen.add(key);}
 });setMatches(found);if(found.length)jump(found,0);}
 function jump(items:Match[],index:number){document.querySelectorAll('.page-discover-match').forEach(el=>el.classList.remove('page-discover-match'));const item=items[index];if(!item?.element.isConnected)return;item.element.classList.add('page-discover-match');item.element.scrollIntoView({block:'center',inline:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});setActive(index);}
 function clear(){setQuery('');setMatches([]);setSearched(false);setActive(-1);document.querySelectorAll('.page-discover-match').forEach(el=>el.classList.remove('page-discover-match'));input.current?.focus();}
 return <form className="page-discover" role="search" aria-label="Discover on this page" onSubmit={e=>{e.preventDefault();search();}}><label htmlFor="page-discover-query">Discover</label><input ref={input} id="page-discover-query" type="search" placeholder="Search this page" value={query} onChange={e=>{setQuery(e.target.value);setSearched(false);setMatches([]);document.querySelectorAll('.page-discover-match').forEach(el=>el.classList.remove('page-discover-match'));}}/><button type="submit" aria-label="Run Discover search">Search</button>{query&&<button type="button" onClick={clear} aria-label="Clear page search">&#215;</button>}{searched&&<div className="page-discover-result"><span role="status">{matches.length?`${active+1} of ${matches.length}`:'No matches on this page'}</span>{matches.length>1&&<><button type="button" aria-label="Previous page match" onClick={()=>jump(matches,(active-1+matches.length)%matches.length)}>&#8593;</button><button type="button" aria-label="Next page match" onClick={()=>jump(matches,(active+1)%matches.length)}>&#8595;</button></>}</div>}</form>;
}
