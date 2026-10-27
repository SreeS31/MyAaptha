 'use client';
import {useEffect,useRef,useState} from 'react';
import Link from 'next/link';
import {requestPhoneCode} from '../lib/api';
import CountryPhoneInput from '../components/CountryPhoneInput';
type Turnstile={render:(element:HTMLElement,options:Record<string,unknown>)=>string;remove:(id:string)=>void;reset:(id:string)=>void};
export default function VerifyPhone(){
 const [phone,setPhone]=useState(''),[token,setToken]=useState(''),[status,setStatus]=useState(''),[busy,setBusy]=useState(false);const container=useRef<HTMLDivElement>(null);const widget=useRef<string | undefined>(undefined);
 useEffect(()=>{const sitekey=process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;if(!sitekey){setStatus('Verification is not configured yet. Please contact support.');return;}let disposed=false;const script=document.createElement('script');script.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';script.async=true;script.onload=()=>{const api=(window as unknown as {turnstile:Turnstile}).turnstile;if(!disposed&&container.current)widget.current=api.render(container.current,{sitekey,action:'phone-verification',callback:(value:string)=>setToken(value),'expired-callback':()=>setToken(''),'error-callback':()=>setToken('')});};document.head.appendChild(script);return()=>{disposed=true;const api=(window as unknown as {turnstile?:Turnstile}).turnstile;if(widget.current)api?.remove(widget.current);script.remove();};},[]);
 const submit=async(event:React.FormEvent)=>{event.preventDefault();setBusy(true);try{await requestPhoneCode(phone,token);setStatus('Code sent. Return to the registration or recovery screen and enter the SMS code.');}catch(error){setStatus((error as Error).message);}finally{setBusy(false);setToken('');const api=(window as unknown as {turnstile?:Turnstile}).turnstile;if(widget.current)api?.reset(widget.current);}};
 return <main className="container account-access-page"><section className="card"><h1>Verify your phone</h1><form onSubmit={submit}><label>Mobile number<CountryPhoneInput required value={phone} onChange={setPhone}/></label><div ref={container}/><button disabled={busy||!token} type="submit">Send verification code</button></form><p role="status">{status}</p><Link href="/auth">Back to sign in</Link></section></main>;
}
