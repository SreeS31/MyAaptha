'use client';
import {useEffect,useRef,useState} from 'react';
import * as api from '../lib/reviewed-trees';
import ReviewedTreeCanvas from './ReviewedTreeCanvas';

type Props={cards:api.TreeCard[];busy:boolean;onEdit:(tree:api.ReviewedTree,node?:string)=>void;onDelete:(card:api.TreeCard)=>void};
export default function SavedTreeDisplay({cards,busy,onEdit,onDelete}:Props){
 const [open,setOpen]=useState<number[]>([]);const viewport=useRef<HTMLDivElement>(null);
 const points:{card:api.TreeCard;x:number;y:number}[]=[];let used=0,ring=0,radius=245;
 while(used<cards.length){radius=245+ring*190;const count=Math.min(cards.length-used,Math.max(6,Math.floor(2*Math.PI*radius/190)));for(let i=0;i<count;i++){const angle=-Math.PI/2+i*2*Math.PI/count;points.push({card:cards[used+i],x:Math.cos(angle)*radius,y:Math.sin(angle)*radius});}used+=count;ring++;}
 const size=Math.max(660,2*(radius+110)),center=size/2;
 useEffect(()=>{const element=viewport.current;if(element){element.scrollLeft=(element.scrollWidth-element.clientWidth)/2;element.scrollTop=(element.scrollHeight-element.clientHeight)/2;}},[size,cards.length]);
 if(!cards.length)return null;
 return <section aria-label="Saved trees circle"><div className="saved-tree-circle-viewport" ref={viewport} tabIndex={0} aria-label="Scrollable circle of saved trees"><div className="saved-tree-circle" style={{width:size,height:size}}><svg width={size} height={size} aria-hidden="true">{points.map(({card,x,y})=><line key={card.id} x1={center} y1={center} x2={center+x} y2={center+y} stroke="#9bbfc1" strokeWidth="2"/>)}</svg><strong className="saved-tree-circle-self" style={{left:center,top:center}}>You</strong>{points.map(({card,x,y})=><button type="button" key={card.id} className="saved-tree-circle-node" style={{left:center+x,top:center+y}} aria-expanded={open.includes(card.id!)} aria-label={`${card.name} (${card.count} people)`} disabled={busy} title={card.name} onClick={()=>setOpen(previous=>previous.includes(card.id!)?previous.filter(id=>id!==card.id!):[...previous,card.id!])}><span>{card.name}</span><small>{card.count} people</small><b aria-hidden="true">{open.includes(card.id!)?'-':'+'}</b></button>)}</div></div>{cards.filter(card=>open.includes(card.id!)).map(card=><SavedTreePanel key={card.id} card={card} busy={busy} onEdit={onEdit} onDelete={onDelete} onClose={()=>setOpen(previous=>previous.filter(id=>id!==card.id!))}/>)}</section>;
}
function SavedTreePanel({card,busy,onEdit,onDelete,onClose}:{card:api.TreeCard;busy:boolean;onEdit:Props['onEdit'];onDelete:Props['onDelete'];onClose:()=>void}){
 const [tree,setTree]=useState<api.ReviewedTree>(),[node,setNode]=useState(''),[loading,setLoading]=useState(true),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 useEffect(()=>{let active=true;setLoading(true);setError('');setTree(undefined);setNode('');api.savedTree(card.id!).then(value=>{if(active)setTree(value);}).catch(e=>{if(active)setError((e as Error).message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[card.id,card.version,retry]);
 const person=tree?.nodes.find(item=>item.key===node);
 return <section id={'saved-tree-'+card.id} className="saved-tree-display" aria-label={'Tree: '+card.name}><header><div><h3>{card.name}</h3><small>{card.count} people</small></div><div className="saved-tree-display-actions"><button disabled={busy||loading||!tree} onClick={()=>tree&&onEdit(tree)}>Edit tree</button><button disabled={busy||loading} onClick={()=>onDelete(card)}>Delete tree</button><button onClick={onClose}>Collapse tree</button></div></header>{loading&&<p role="status">Loading tree...</p>}{error&&<div role="alert">{error}<button onClick={()=>setRetry(value=>value+1)}>Retry</button></div>}{tree&&<><ReviewedTreeCanvas key={`${tree.id}:${tree.version}`} nodes={tree.nodes} connectRoots rootInitiallyOpen rootName={card.name} selected={node} onSelect={setNode}/>{person&&<div className="saved-tree-person"><span><strong>{person.name}</strong> - {person.relation}</span><button disabled={busy} onClick={()=>onEdit(tree,person.key)}>Edit person</button></div>}</>}</section>;
}
