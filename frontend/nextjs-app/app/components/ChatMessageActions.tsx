'use client';
import {ReactNode,useEffect,useRef,useState} from 'react';
import {createPortal} from 'react-dom';
import ForwardMessageDialog from './ForwardMessageDialog';

type Props={id:number;sourceType:'DIRECT'|'CIRCLE';conversationId:number;message:string;deleted:boolean;starred:boolean;pinned:boolean;forwarded:boolean;myReaction?:string|null;canDeleteForAll:boolean;info:ReactNode;onReply?:()=>void;onEdit?:()=>Promise<void>;onFlags:(flags:{starred?:boolean;pinned?:boolean})=>Promise<void>;onReact:(emoji:string)=>Promise<void>;onDeleteForMe:()=>Promise<void>;onDeleteForAll:()=>Promise<void>;onDownload?:()=>Promise<void>;onInfo?:()=>void;onPrivateReply?:()=>void;onMessageAuthor?:()=>void;onReport?:()=>Promise<void>;hideIndicators?:boolean};
export default function ChatMessageActions(props:Props){
  const [panel,setPanel]=useState<'actions'|'react'|'delete'|null>(null),[forward,setForward]=useState(false),[info,setInfo]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState('');
  const trigger=useRef<HTMLButtonElement>(null),popup=useRef<HTMLDivElement>(null),infoDialog=useRef<HTMLDialogElement>(null);
  const [position,setPosition]=useState({top:0,left:0});
  function close(){setPanel(null);trigger.current?.focus({preventScroll:true});}
  function open(value:'actions'|'react'){const box=trigger.current?.getBoundingClientRect();if(box)setPosition({top:Math.max(8,Math.min(box.bottom+4,window.innerHeight-390)),left:Math.max(8,Math.min(box.right-210,window.innerWidth-290))});setPanel(value);}
  useEffect(()=>{if(!panel)return;popup.current?.querySelector<HTMLButtonElement>('button')?.focus();function outside(event:PointerEvent){if(!popup.current?.contains(event.target as Node)&&!trigger.current?.contains(event.target as Node))setPanel(null);}document.addEventListener('pointerdown',outside);return()=>document.removeEventListener('pointerdown',outside);},[panel]);
  useEffect(()=>{if(info)infoDialog.current?.showModal();},[info]);
  async function run(action:()=>Promise<void>){if(busy)return;setBusy(true);setError('');try{await action();close();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
  const action=(label:string,icon:string,callback:()=>void)=><button role="menuitem" className={label.startsWith('Delete')?'chat-menu-danger':undefined} disabled={busy} key={label} onClick={callback}><span aria-hidden="true">{icon}</span>{label}</button>;
  return <div className="compact-chat-actions">
    {!props.hideIndicators&&props.forwarded&&!props.deleted&&<small>Forwarded</small>}{!props.hideIndicators&&props.starred&&<span title="Starred" aria-label="Starred">☆</span>}{!props.hideIndicators&&props.pinned&&<span title="Pinned for me" aria-label="Pinned for me">⌖</span>}
    {!props.deleted&&<button className="chat-action-trigger" aria-label={`React to message ${props.id}`} onClick={()=>open('react')}>☺</button>}
    <button ref={trigger} className="chat-action-trigger" aria-label={`Actions for message ${props.id}`} aria-haspopup="menu" aria-expanded={panel!==null} onClick={()=>panel?close():open('actions')}>⌄</button>
    {panel&&createPortal(<div ref={popup} className={`chat-context-menu ${panel==='react'?'chat-reaction-picker':''}`} style={position} role="menu" aria-label={panel==='react'?'Message reactions':panel==='delete'?'Delete message':'Message actions'} onKeyDown={event=>{
      if(event.key==='Escape'){event.preventDefault();event.stopPropagation();close();}
      if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)){event.preventDefault();const buttons=Array.from(popup.current?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')||[]);const current=buttons.indexOf(document.activeElement as HTMLButtonElement);buttons[event.key==='Home'?0:event.key==='End'?buttons.length-1:(current+(event.key==='ArrowUp'?-1:1)+buttons.length)%buttons.length]?.focus();}
      if(event.key==='Tab')close();
    }}>
      {panel==='react'?['👍','❤️','😂','😮','😢','🙏'].map(emoji=><button role="menuitem" key={emoji} disabled={busy} aria-label={`React ${emoji}`} onClick={()=>void run(()=>props.onReact(props.myReaction===emoji?'':emoji))}>{emoji}</button>):panel==='delete'?<>
        {action('Delete for me','⌫',()=>void run(props.onDeleteForMe))}
        {props.canDeleteForAll&&action('Delete for all','⌫',()=>{if(confirm('Delete this message for everyone?'))void run(props.onDeleteForAll);})}
      </>:<>
        {action('Info','ⓘ',()=>{close();if(props.onInfo)props.onInfo();else setInfo(true);})}
        {!props.deleted&&<>{props.onReply&&action('Reply','↩',()=>{close();props.onReply?.();})}
          {props.onPrivateReply&&action('Reply privately','\u21a9',()=>{close();props.onPrivateReply?.();})}{props.onMessageAuthor&&action('Message sender','\u2709',()=>{close();props.onMessageAuthor?.();})}
          {props.message&&action('Copy','▣',()=>void run(()=>navigator.clipboard.writeText(props.message)))}
          {action('React','☺',()=>setPanel('react'))}
          {props.onDownload&&action('Download','↓',()=>void run(props.onDownload!))}
          {action('Forward','↪',()=>{close();setForward(true);})}
          {action(props.pinned?'Unpin for me':'Pin for me','⌖',()=>void run(()=>props.onFlags({pinned:!props.pinned})))}
          {action(props.starred?'Unstar':'Star','☆',()=>void run(()=>props.onFlags({starred:!props.starred})))}
          {props.onEdit&&action('Edit','✎',()=>void run(props.onEdit!))}
        </>}
        {props.onReport&&action('Report','!',()=>void run(props.onReport!))}<hr/>{action('Delete','⌫',()=>setPanel('delete'))}
      </>}
    </div>,document.body)}
    {forward&&<ForwardMessageDialog sourceType={props.sourceType} conversationId={props.conversationId} messageId={props.id} onClose={()=>{setForward(false);trigger.current?.focus();}} onSent={()=>{setForward(false);setNotice('Message forwarded.');trigger.current?.focus();}}/>}
    {info&&createPortal(<dialog ref={infoDialog} className="chat-info-dialog" aria-label="Message info" onCancel={()=>setInfo(false)}><header><h2>Message info</h2><button onClick={()=>setInfo(false)}>Close</button></header>{props.info}<p>Stars and pins are private to you.</p></dialog>,document.body)}
    {busy&&<small role="status">Updating…</small>}{error&&<p role="alert">{error}</p>}{notice&&<small role="status">{notice}</small>}
  </div>;
}
