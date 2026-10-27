'use client';

import {FormEvent,useCallback,useEffect,useRef,useState} from 'react';
import InfoTip from '../components/InfoTip';
import FinanceIcon from './FinanceIcon';
import {attachRenewalReceipt,deleteRenewal,fetchRenewalReceipt,fetchRenewals,isUnauthorizedError,removeRenewalReceipt,RenewalInput,RenewalItem,saveRenewal,setRenewalState} from '../lib/api';
import {startPolling} from '../lib/polling';
import './renewals.css';

const zones=['Asia/Kolkata','UTC','Asia/Dubai','Asia/Singapore','Europe/London','America/New_York','America/Los_Angeles','Australia/Sydney'];
const date=(value:string)=>new Date(`${value}T12:00:00`).toLocaleDateString(undefined,{day:'numeric',month:'short',year:'numeric'});
const money=(value:number)=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:2}).format(value);
const empty=():RenewalInput=>({kind:'BILL',title:'',provider:'',referenceNumber:'',amount:null,purchasedOn:null,expiresOn:'',timezone:'Asia/Kolkata',notes:'',remindersEnabled:true,archived:false});
const label=(item:RenewalItem)=>item.archived?'Archived':item.daysRemaining<0?`Expired ${Math.abs(item.daysRemaining)}d ago`:item.daysRemaining===0?'Due today':`${item.daysRemaining} days left`;

export default function RenewalTracker(){
  const [items,setItems]=useState<RenewalItem[]>([]),[loading,setLoading]=useState(true),[error,setError]=useState(''),[notice,setNotice]=useState('');
  const [filter,setFilter]=useState('active'),[query,setQuery]=useState('');
  const [editing,setEditing]=useState<number>(),[intent,setIntent]=useState('Add bill or warranty'),[draft,setDraft]=useState<RenewalInput>(empty);
  const [receipt,setReceipt]=useState<File|null>(null),[existingReceipt,setExistingReceipt]=useState<string|null>(null),[removeReceipt,setRemoveReceipt]=useState(false);
  const [saving,setSaving]=useState(false),[formError,setFormError]=useState(''),[deleting,setDeleting]=useState<RenewalItem|null>(null);
  const editor=useRef<HTMLDialogElement>(null),confirmation=useRef<HTMLDialogElement>(null);
  const loadSequence=useRef(0);
  const load=useCallback(async()=>{const sequence=++loadSequence.current;try{const rows=await fetchRenewals();if(sequence===loadSequence.current){setItems(rows);setError('');}}catch(e){if(sequence===loadSequence.current)setError(isUnauthorizedError(e)?'Sign in to manage your bills and warranties.':(e as Error).message);}finally{if(sequence===loadSequence.current)setLoading(false);}},[]);
  useEffect(()=>startPolling(load,30000),[load]);
  const open=(item?:RenewalItem,renew=false,kind:RenewalInput['kind']='BILL')=>{
    setEditing(item?.id);setIntent(renew?'Renew item':item?'Edit bill or warranty':'Add bill or warranty');
    setDraft(item?{...item,archived:renew?false:item.archived,expiresOn:renew?'':item.expiresOn}:{...empty(),kind,timezone:Intl.DateTimeFormat().resolvedOptions().timeZone||'Asia/Kolkata'});
    setReceipt(null);setExistingReceipt(item?.attachmentName||null);setRemoveReceipt(false);setFormError('');editor.current?.showModal();
  };
  const change=<K extends keyof RenewalInput>(key:K,value:RenewalInput[K])=>setDraft(previous=>({...previous,[key]:value}));
  async function submit(event:FormEvent){
    event.preventDefault();setSaving(true);setFormError('');let saved:RenewalItem|undefined;
    try{
      saved=await saveRenewal(draft,editing);setEditing(saved.id);
      if(intent==='Add bill or warranty'||intent==='Renew item'){setFilter('active');setQuery('');}
      if(receipt)await attachRenewalReceipt(saved.id,receipt);else if(removeReceipt)await removeRenewalReceipt(saved.id);
      setNotice(intent==='Renew item'?'Renewal date updated. Your reminder schedule has restarted.':'Bill or warranty saved.');await load();editor.current?.close();
    }catch(e){setFormError(`${saved?'Details saved; receipt update failed. Retry or cancel to keep the saved details. ':''}${(e as Error).message}`);if(saved)await load();}
    finally{setSaving(false);}
  }
  async function download(item:RenewalItem){try{const blob=await fetchRenewalReceipt(item.id),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=item.attachmentName||'receipt';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}catch(e){setError((e as Error).message);}}
  async function archive(item:RenewalItem){setSaving(true);try{await setRenewalState(item.id,{archived:!item.archived});setNotice(item.archived?'Item restored.':'Item archived; reminders stopped.');await load();}catch(e){setError((e as Error).message);}finally{setSaving(false);}}
  const visible=items.filter(item=>filter==='archived'?item.archived:!item.archived&&(filter!=='soon'||item.daysRemaining>=0&&item.daysRemaining<=30)&&(filter!=='expired'||item.daysRemaining<0)).filter(item=>`${item.title} ${item.provider} ${item.referenceNumber}`.toLowerCase().includes(query.toLowerCase()));
  const current=items.filter(item=>!item.archived);
  const distribution=[{label:'Expired',tone:'expired',count:current.filter(item=>item.daysRemaining<0).length},{label:'Due soon',tone:'soon',count:current.filter(item=>item.daysRemaining>=0&&item.daysRemaining<=30).length},{label:'Later',tone:'later',count:current.filter(item=>item.daysRemaining>30).length}];
  return <section id="renewals" className="renewal-tracker card" aria-labelledby="renewals-title" aria-busy={loading}>
    <header className="renewal-heading"><div><span className="renewal-eyebrow">PLAN AHEAD</span><h2 id="renewals-title">Bills &amp; warranties <InfoTip label="About renewal reminders">Keep invoices, service plans and warranty dates together. Reminders are created at 9am in the selected time zone, 30, 15, 7, 3 and 1 day before expiry. Email, SMS and push follow your notification settings and configured providers. Missed dates are skipped rather than sent in a batch. Renewing does not record a payment.</InfoTip></h2></div><button className="btn btn-primary" onClick={()=>open()}>+ Add bill or warranty</button></header>
    <div className="renewal-stats"><button type="button" className="renewal-stat due" aria-pressed={filter==='soon'} onClick={()=>setFilter('soon')}><span className="renewal-stat-icon"><FinanceIcon name="calendar"/></span><span><b>{loading?'...':items.filter(x=>!x.archived&&x.daysRemaining>=0&&x.daysRemaining<=30).length}</b><small>Due within 30 days</small></span></button><button type="button" className="renewal-stat overdue" aria-pressed={filter==='expired'} onClick={()=>setFilter('expired')}><span className="renewal-stat-icon"><FinanceIcon name="bill"/></span><span><b>{loading?'...':items.filter(x=>!x.archived&&x.daysRemaining<0).length}</b><small>Expired items</small></span></button><div className="renewal-schedule"><span>Reminders before expiry</span><span className="renewal-milestones" aria-label="Reminder days before expiry">{[30,15,7,3,1].map(day=><b key={day}>{day}<small>d</small></b>)}</span></div></div>
    {!loading&&current.length>0&&<figure className="renewal-distribution" aria-label="Current renewal expiry overview"><div className="renewal-distribution-bar" role="img" aria-label={distribution.map(item=>`${item.label}: ${item.count}`).join(', ')}>{distribution.filter(item=>item.count>0).map(item=><span key={item.tone} className={item.tone} style={{flex:item.count}}/>)}</div><figcaption>{distribution.map(item=><span key={item.tone}><i className={item.tone}/>{item.label} <b>{item.count}</b></span>)}</figcaption></figure>}
    {error&&<p role="alert" className="error-message">{error} <button type="button" onClick={()=>{setLoading(true);void load();}}>Try again</button></p>}{notice&&<p role="status" className="renewal-success">{notice}</p>}
    {items.length>0&&<div className="renewal-tools"><label>Show<select value={filter} onChange={e=>setFilter(e.target.value)}><option value="active">All current items</option><option value="soon">Due within 30 days</option><option value="expired">Expired</option><option value="archived">Archived</option></select></label><label>Search bills and warranties<input type="search" value={query} onChange={e=>setQuery(e.target.value)} placeholder="Name, provider or reference"/></label></div>}
    {loading?<p role="status">Loading bills and warranties...</p>:<div className="renewal-grid">{visible.map(item=><article id={`renewal-${item.id}`} className={`renewal-card ${item.status.toLowerCase()}`} key={item.id} aria-label={item.title}>
      <header><span className="renewal-kind"><FinanceIcon name={item.kind==='BILL'?'bill':item.kind==='WARRANTY'?'warranty':'service'}/>{item.kind==='BILL'?'Bill':item.kind==='WARRANTY'?'Warranty':'Service plan'}</span><span className="renewal-badge">{label(item)}</span></header>
      <h3>{item.title}</h3>{item.provider&&<p className="renewal-provider">{item.provider}</p>}
      <dl><div><dt>{item.kind==='BILL'?'Due date':'Expiry date'}</dt><dd>{date(item.expiresOn)}</dd></div>{item.amount!=null&&<div><dt>Amount (INR)</dt><dd>{money(item.amount)}</dd></div>}{item.referenceNumber&&<div><dt>Reference</dt><dd>{item.referenceNumber}</dd></div>}</dl>
      <p className="renewal-reminder-status">{item.archived?'Reminders stopped':!item.remindersEnabled?'Reminders paused':item.nextReminderAt?`Next reminder: ${new Date(item.nextReminderAt).toLocaleString(undefined,{timeZone:item.timezone,dateStyle:'medium',timeStyle:'short'})} (${item.timezone})`:'No reminders remaining'}</p>
      {item.notes&&<details><summary>Notes</summary><p>{item.notes}</p></details>}
      {item.attachmentUrl&&<button type="button" className="renewal-receipt" onClick={()=>void download(item)}><FinanceIcon name="bill"/>Receipt: {item.attachmentName}</button>}
      <footer><button className="btn btn-secondary" disabled={saving} onClick={()=>open(item)}>Edit</button><button className="btn btn-primary" disabled={saving} onClick={()=>open(item,true)}>Renew</button><button className="btn btn-secondary" disabled={saving} onClick={()=>void archive(item)}>{item.archived?'Restore':'Archive'}</button><button className="btn btn-danger" disabled={saving} aria-label={`Delete ${item.title}`} onClick={()=>{setDeleting(item);confirmation.current?.showModal();}}>Delete</button></footer>
    </article>)}</div>}
    {!loading&&!visible.length&&<div className={`renewal-empty ${items.length?'filtered':''}`}><div className="renewal-empty-visual" aria-hidden="true"><FinanceIcon name="calendar"/><span>&#10003;</span></div><div><span className="renewal-eyebrow">{items.length?'A CLEAR VIEW':'A SMALL STEP TODAY'}</span><h3>{items.length?'No matching items':'Your next renewal, remembered'}</h3><p>{items.length?'Try another filter or search.':'Keep bills, warranties and service dates together. Choose an item to get started.'}</p>{items.length?<button className="btn btn-secondary" onClick={()=>{setFilter('active');setQuery('');}}>Clear filters</button>:<div className="renewal-quick-start"><button type="button" onClick={()=>open(undefined,false,'BILL')}><FinanceIcon name="bill"/>Add bill</button><button type="button" onClick={()=>open(undefined,false,'WARRANTY')}><FinanceIcon name="warranty"/>Add warranty</button><button type="button" onClick={()=>open(undefined,false,'SERVICE')}><FinanceIcon name="service"/>Add service plan</button></div>}</div></div>}
    <dialog ref={editor} className="renewal-dialog" aria-labelledby="renewal-editor-title" onCancel={event=>{if(saving)event.preventDefault();}}>
      <form onSubmit={submit} aria-busy={saving}><header><h2 id="renewal-editor-title">{intent}</h2><button type="button" className="btn btn-secondary" aria-label="Close bill or warranty editor" disabled={saving} onClick={()=>editor.current?.close()}>Close</button></header>
        {formError&&<p role="alert" className="error-message">{formError}</p>}
        <fieldset disabled={saving} className="renewal-fields"><label>Item type<select value={draft.kind} onChange={e=>change('kind',e.target.value as RenewalInput['kind'])}><option value="BILL">Bill</option><option value="WARRANTY">Warranty</option><option value="SERVICE">Service plan</option></select></label>
        <label>Title<input autoFocus required maxLength={160} value={draft.title} onChange={e=>change('title',e.target.value)} placeholder="e.g. Car insurance or washing machine"/></label>
        <label>Provider or store<input maxLength={160} value={draft.provider||''} onChange={e=>change('provider',e.target.value)}/></label>
        <label>Invoice or reference number<input maxLength={160} value={draft.referenceNumber||''} onChange={e=>change('referenceNumber',e.target.value)}/></label>
        <label>Amount (INR, optional)<input type="number" min="0" max="1000000000000" step="0.01" value={draft.amount??''} onChange={e=>change('amount',e.target.value===''?null:Number(e.target.value))}/></label>
        <label>Purchase or start date<input type="date" min="1900-01-01" max={draft.expiresOn||'9999-12-31'} value={draft.purchasedOn||''} onChange={e=>change('purchasedOn',e.target.value||null)}/></label>
        <label>{draft.kind==='BILL'?'Due date':'Expiry date'}<input required type="date" min={draft.purchasedOn||'1900-01-01'} max="9999-12-31" value={draft.expiresOn} onChange={e=>change('expiresOn',e.target.value)}/></label>
        <label>Reminder time zone<select value={draft.timezone} onChange={e=>change('timezone',e.target.value)}>{Array.from(new Set([draft.timezone,...zones])).map(zone=><option key={zone}>{zone}</option>)}</select></label>
        <label className="renewal-wide">Notes<textarea maxLength={2000} value={draft.notes||''} onChange={e=>change('notes',e.target.value)} rows={2}/></label>
        <label className="renewal-toggle"><input type="checkbox" checked={draft.remindersEnabled} onChange={e=>change('remindersEnabled',e.target.checked)}/>Remind me before expiry</label>
        <div className="renewal-wide renewal-upload"><label>Receipt (optional)<input type="file" accept="application/pdf,image/jpeg,image/png,image/webp" onChange={e=>{const file=e.target.files?.[0]||null;if(file&&file.size>25*1024*1024){setFormError('Choose a receipt of 25 MB or smaller.');e.target.value='';return;}setReceipt(file);setFormError('');}}/></label><small>PDF, JPG, PNG or WebP. Up to your account upload limit, maximum 25 MB.</small>{existingReceipt&&<label className="renewal-toggle"><input type="checkbox" checked={removeReceipt} onChange={e=>setRemoveReceipt(e.target.checked)}/>Remove current receipt: {existingReceipt}</label>}</div>
        </fieldset><footer><button type="button" className="btn btn-secondary" disabled={saving} onClick={()=>editor.current?.close()}>Cancel</button><button className="btn btn-primary" disabled={saving}>{saving?'Saving...':intent==='Renew item'?'Save renewal':'Save item'}</button></footer>
      </form>
    </dialog>
    <dialog ref={confirmation} className="renewal-dialog renewal-confirmation" aria-labelledby="renewal-delete-title" onCancel={event=>{if(saving)event.preventDefault();}}><h2 id="renewal-delete-title">Delete this item?</h2><p>{deleting?.title} and its receipt will be removed. Future reminders will stop.</p><footer><button className="btn btn-secondary" disabled={saving} onClick={()=>confirmation.current?.close()}>Cancel</button><button className="btn btn-danger" disabled={saving} onClick={async()=>{if(!deleting)return;setSaving(true);try{await deleteRenewal(deleting.id);confirmation.current?.close();setNotice('Item removed; future reminders stopped.');await load();}catch(e){setError((e as Error).message);confirmation.current?.close();}finally{setSaving(false);}}}>{saving?'Deleting...':'Delete item'}</button></footer></dialog>
  </section>;
}
