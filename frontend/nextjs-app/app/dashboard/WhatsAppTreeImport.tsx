'use client';
import {useState} from 'react';
import type {ReviewedTree} from '../lib/reviewed-trees';
import {whatsappGroupName,whatsappMemberNames} from '../lib/whatsapp-tree-import';
import ReviewedTreeWorkspace from './ReviewedTreeWorkspace';

export default function WhatsAppTreeImport(){
 const [name,setName]=useState(''),[text,setText]=useState(''),[kind,setKind]=useState<'members'|'chat'>('members'),[error,setError]=useState(''),[draft,setDraft]=useState<ReviewedTree>();
 function review(){
  setError('');
  try{
   const names=whatsappMemberNames(text,kind);
   if(!name.trim())throw new Error('Enter the WhatsApp group name.');
   if(names.length<3)throw new Error('Add at least 3 people. Chat exports may miss silent members; add them using a member list.');
   if(names.length>50000)throw new Error('A tree supports up to 50,000 people. Split this list into smaller trees.');
   setDraft({id:null,sourceKey:null,name:name.trim(),reason:kind==='chat'?'WhatsApp export: detected speakers only; current membership is not verified.':'WhatsApp group: member list supplied by you; current membership is not verified.',confidence:'Needs review',version:0,nodes:names.map((member,i)=>({key:'wa'+i,contactId:null,name:member,relation:'Member',parentKey:null,gender:'UNSPECIFIED'}))});
  }catch(e){setError((e as Error).message);}
 }
 return <section className="reviewed-trees-workspace" aria-label="WhatsApp group import"><h2>WhatsApp groups</h2>
 <p>Import a group as a private tree. Direct personal-account sync is unavailable.</p>
 <details><summary>How to import</summary><p>Open WhatsApp group info to review members. Paste one person per line below. Alternatively, export the chat without media and choose Chat export. Exports identify speakers, not the complete current member list.</p><p>Text is processed on this device. Only the names and connections you review and save go to MyAaptha. Group membership does not establish family relationships or gender. Saving does not invite or message anyone.</p><a href="https://faq.whatsapp.com/1180414079177245/" target="_blank" rel="noreferrer">WhatsApp export instructions</a></details>
 <div className="reviewed-contact-picker"><label>Group name<input maxLength={200} value={name} onChange={e=>setName(e.target.value)} placeholder="Same name as your WhatsApp group"/></label>
 <label>Import source<select aria-label="Import source" value={kind} onChange={e=>{setKind(e.target.value as 'members'|'chat');setText('');setError('');}}><option value="members">Member list</option><option value="chat">Chat export (speakers only)</option></select></label>
 <label>Text file<input type="file" accept=".txt,text/plain" onChange={async e=>{const file=e.target.files?.[0];e.target.value='';if(!file)return;setError('');try{if(file.size>5_000_000)throw new Error('Use a text file smaller than 5 MB.');const value=await file.text();setText(value);if(!name.trim())setName(whatsappGroupName(file.name));}catch(err){setError((err as Error).message);}}}/></label>
 <label>{kind==='members'?'Members (one per line)':'Exported chat text'}<textarea rows={7} maxLength={5_000_000} value={text} onChange={e=>setText(e.target.value)}/></label>
 {kind==='chat'&&<p>Silent members may be missing, former members may appear, and equal display names are combined. Review and correct the people before saving.</p>}
 {error&&<p role="alert">{error}</p>}<button disabled={!name.trim()||!text.trim()} onClick={review}>Review group tree</button><button onClick={()=>{setText('');setName('');setError('');setDraft(undefined);}}>Clear import</button></div>
 <ReviewedTreeWorkspace mode="saved" importedTree={draft} importOnly/>
 </section>;
}
