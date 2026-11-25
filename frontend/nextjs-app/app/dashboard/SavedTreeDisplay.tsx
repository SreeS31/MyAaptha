'use client';
import {useEffect,useState} from 'react';
import * as api from '../lib/reviewed-trees';
import ReviewedTreeCanvas from './ReviewedTreeCanvas';

export default function SavedTreeDisplay({cards,busy,onEdit,onDelete}:{cards:api.TreeCard[];busy:boolean;onEdit:(tree:api.ReviewedTree,node?:string)=>void;onDelete:(card:api.TreeCard)=>void}){
 const [chosen,setChosen]=useState<number|null>(null),[tree,setTree]=useState<api.ReviewedTree>(),[node,setNode]=useState(''),[loading,setLoading]=useState(false),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 const card=cards.find(item=>item.id===chosen)||cards[0];
 useEffect(()=>{if(!card?.id)return;let active=true;setLoading(true);setError('');setTree(undefined);setNode('');api.savedTree(card.id).then(value=>{if(active)setTree(value);}).catch(e=>{if(active)setError((e as Error).message);}).finally(()=>{if(active)setLoading(false);});return()=>{active=false;};},[card?.id,cards,retry]);
 if(!card)return null;
 const displayed=tree?.id===card.id?tree:undefined;
 const person=displayed?.nodes.find(item=>item.key===node);
 return <section className="saved-tree-display" aria-label="Saved tree diagram"><header><div><h3>{displayed?.name||card.name}</h3><small>{displayed?.nodes.length??card.count} people</small></div><div className="saved-tree-display-actions"><label>Tree<select aria-label="Choose a saved tree" value={card.id!} disabled={busy} onChange={e=>setChosen(Number(e.target.value))}>{cards.map(item=><option key={item.id} value={item.id!}>{item.name} ({item.count})</option>)}</select></label><button disabled={busy||loading||!displayed} onClick={()=>displayed&&onEdit(displayed)}>Edit tree</button><button disabled={busy||loading} onClick={()=>onDelete(card)}>Delete tree</button></div></header>{loading&&<p role="status">Loading tree...</p>}{error&&<div role="alert">{error}<button onClick={()=>setRetry(value=>value+1)}>Retry</button></div>}{displayed&&<><ReviewedTreeCanvas key={`${displayed.id}:${displayed.version}`} nodes={displayed.nodes} initiallyExpanded connectRoots selected={node} onSelect={setNode}/>{person&&<div className="saved-tree-person"><span><strong>{person.name}</strong> · {person.relation}</span><button disabled={busy} onClick={()=>onEdit(displayed!,person.key)}>Edit person</button></div>}</>}</section>;
}
