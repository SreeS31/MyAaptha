'use client';
import Link from 'next/link';
import {useState} from 'react';
import {AddressContact,fetchAddressBook,NetworkCircle} from '../lib/api';
import styles from './page.module.css';

export default function CircleBranch({circle,privateCount,expanded,onToggle}:{circle:NetworkCircle;privateCount:number;expanded:boolean;onToggle:()=>void}){
  const [contacts,setContacts]=useState<AddressContact[]>([]),[cursor,setCursor]=useState<number|null>(null);
  const [loaded,setLoaded]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState('');
  async function loadMore(){
    if(busy)return;setBusy(true);setError('');
    try{const page=await fetchAddressBook('',loaded?cursor||0:0,circle.id);setContacts(current=>loaded?[...current,...page.items]:page.items);setCursor(page.nextCursor);setLoaded(true);}
    catch(caught){setError(caught instanceof Error?caught.message:'Contacts could not be loaded.');}
    finally{setBusy(false);}
  }
  return <article className={styles.branch}>
    <button type="button" className={styles.circleNode} aria-label={`Open ${circle.name}`} aria-expanded={expanded} aria-controls={`circle-branch-${circle.id}`} onClick={onToggle}>
      <span className={styles.marker} aria-hidden="true">{expanded?'−':'+'}</span><span><strong>{circle.name}</strong><small>{circle.members.length} {circle.members.length===1?'member':'members'}{privateCount>0?` · ${privateCount} private contacts`:''}</small></span>
    </button>
    {expanded&&<div id={`circle-branch-${circle.id}`} className={styles.children}>
      <div className={styles.actions}><Link href={`/messages?circle=${circle.id}`}>Messages</Link>{circle.ownedByCurrentUser&&<Link href={`/contacts?circleId=${circle.id}`}>Manage contacts</Link>}</div>
      {circle.description&&<p className={styles.description}>{circle.description}</p>}
      <ul aria-label={`${circle.name} members`} className={styles.people}>{circle.members.map(member=><li key={member.person.id}><Link href={`/people/${member.person.id}`} className={styles.person}><span aria-hidden="true" className={styles.avatar}>{member.person.displayName.charAt(0)}</span><span>{member.person.displayName}<small>{member.creator?'Creator':member.admin?'Admin':'Member'}</small></span></Link></li>)}</ul>
      {privateCount>0&&<section aria-label={`${circle.name} private contacts`} className={styles.privateBranch}>
        <button type="button" className="btn btn-secondary" onClick={loadMore} disabled={busy||loaded&&cursor===null}>{busy?'Loading…':!loaded?`Show private contacts (${privateCount})`:cursor!==null?'Load more contacts':'All contacts shown'}</button>
        {error&&<p role="alert">{error}</p>}
        <ul className={styles.people}>{contacts.map(contact=><li key={contact.id}><div className={styles.person}><span aria-hidden="true" className={styles.avatar}>{contact.displayName?.charAt(0)||'○'}</span><span>{contact.displayName||contact.emails[0]||contact.phones[0]||'Contact'}<small>Private contact</small></span></div></li>)}</ul>
      </section>}
    </div>}
  </article>;
}
