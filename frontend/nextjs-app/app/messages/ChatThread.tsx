'use client';
import {attachmentAccept} from '../lib/upload-security';
import {Fragment,useCallback,useEffect,useRef,useState} from 'react';
import * as api from '../lib/api';
import {mergeMessagePage} from '../lib/message-pages';
import {startPolling} from '../lib/polling';
import ChatMessageActions from '../components/ChatMessageActions';
import MessageTimestamp,{chatDay} from '../components/MessageTimestamp';

export type OpenChat={type:'DIRECT'|'CIRCLE';id:number;name:string;photo?:string|null;draft?:string;search?:string};
type Message=api.DirectMessage|api.CirclePost;
const author=(message:Message)=>'senderName' in message?message.senderName:message.authorName;
const authorId=(message:Message)=>'senderId' in message?message.senderId:message.authorId;
const parentId=(message:Message)=>'senderId' in message?message.replyToMessageId:message.parentPostId;

function Attachment({message,chat}:{message:Message;chat:OpenChat}){
  const [url,setUrl]=useState(''),[error,setError]=useState('');
  useEffect(()=>{let active=true,objectUrl='';if(!message.attachmentUrl)return;const task=chat.type==='DIRECT'?api.fetchDirectMessageAttachment(chat.id,message.id):api.fetchCircleAttachment(chat.id,message.id);task.then(blob=>{if(active){objectUrl=URL.createObjectURL(blob);setUrl(objectUrl);}}).catch(()=>{if(active)setError('Attachment unavailable');});return()=>{active=false;if(objectUrl)URL.revokeObjectURL(objectUrl);};},[chat.type,chat.id,message.id,message.attachmentUrl]);
  if(!message.attachmentUrl)return null;if(error)return <small>{error}</small>;if(!url)return <small>Loading attachment…</small>;
  if(message.attachmentType?.startsWith('image/'))return <a href={url} target="_blank" rel="noreferrer"><img className="chat-media-image" src={url} alt={message.attachmentName||'Photo'}/></a>;
  if(message.attachmentType?.startsWith('video/'))return <video className="chat-media-image" src={url} controls preload="metadata"/>;
  if(message.attachmentType?.startsWith('audio/'))return <audio src={url} controls preload="metadata"/>;
  return <a className="chat-document" href={url} download={message.attachmentName||'attachment'}>↓ {message.attachmentName||'Download attachment'}</a>;
}

export default function ChatThread({chat,onBack,onChanged,onOpenPerson}:{chat:OpenChat;onBack:()=>void;onChanged:()=>void;onOpenPerson:(chat:OpenChat)=>void}){
  const direct=chat.type==='DIRECT';
  const [messages,setMessages]=useState<Message[]>([]),[loading,setLoading]=useState(true),[error,setError]=useState(''),[draft,setDraft]=useState(chat.draft||''),[file,setFile]=useState<File|null>(null),[sending,setSending]=useState(false),[progress,setProgress]=useState<number|null>(null);
  const [reply,setReply]=useState<Message|null>(null),[info,setInfo]=useState<Message|null>(null),[searchOpen,setSearchOpen]=useState(Boolean(chat.search)),[search,setSearch]=useState(chat.search||''),[results,setResults]=useState<Message[]|null>(null),[filter,setFilter]=useState('all'),[emojiOpen,setEmojiOpen]=useState(false),[canPost,setCanPost]=useState(direct),[presence,setPresence]=useState<api.PresenceStatus|null>(null),[hasEarlier,setHasEarlier]=useState(false),[newMessages,setNewMessages]=useState(false);
  useEffect(()=>{if(chat.search){setSearch(chat.search);setSearchOpen(true);}},[chat.search]);
  const list=useRef<HTMLDivElement>(null),input=useRef<HTMLTextAreaElement>(null),initial=useRef(true),acknowledged=useRef(new Set<number>()),lastTyping=useRef(0),busyLoad=useRef(false),alive=useRef(true),latestId=useRef(0);
  const nearBottom=()=>!list.current||list.current.scrollHeight-list.current.scrollTop-list.current.clientHeight<100;
  const bottom=()=>{list.current?.scrollTo({top:list.current.scrollHeight,behavior:'auto'});setNewMessages(false);};
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  const load=useCallback(async()=>{
    if(busyLoad.current||document.hidden)return;busyLoad.current=true;
    try{const page=direct?await api.fetchDirectMessages(chat.id):await api.fetchCirclePosts(chat.id);if(!alive.current)return;
      const follow=initial.current||nearBottom();setMessages(current=>mergeMessagePage(current,page));if(initial.current)setHasEarlier(page.length===50);setLoading(false);setError('');initial.current=false;if(follow)requestAnimationFrame(bottom);else if(page.some(message=>message.id>latestId.current))setNewMessages(true);latestId.current=Math.max(latestId.current,...page.map(message=>message.id));
    }catch(e){if(alive.current){setError((e as Error).message);setLoading(false);}}finally{busyLoad.current=false;}
  },[chat.id,direct]);
  useEffect(()=>startPolling(load,6000),[load]);
  useEffect(()=>{if(!direct)api.fetchMyCircles().then(circles=>{if(alive.current)setCanPost(circles.some(c=>c.id===chat.id&&c.currentUserCanPost));}).catch(e=>setError(e.message));},[chat.id,direct]);
  useEffect(()=>startPolling(async()=>{await api.heartbeatPresence();const value=direct?await api.fetchDirectPresence(chat.id):await api.fetchCirclePresence(chat.id);if(alive.current)setPresence(value);},20000),[chat.id,direct]);
  useEffect(()=>{if(!search.trim()){setResults(null);return;}let active=true;const timer=setTimeout(()=>{(direct?api.searchDirectMessages(chat.id,search):api.searchCirclePosts(chat.id,search)).then(values=>{if(active)setResults(values);}).catch(e=>{if(active)setError(e.message);});},300);return()=>{active=false;clearTimeout(timer);};},[search,chat.id,direct]);
  useEffect(()=>{
    if(!direct||!list.current)return;
    const observer=new IntersectionObserver(entries=>{const ids=entries.filter(entry=>entry.isIntersecting&&entry.intersectionRatio>=.6&&document.visibilityState==='visible').map(entry=>Number((entry.target as HTMLElement).dataset.messageId)).filter(id=>!acknowledged.current.has(id));if(!ids.length)return;ids.forEach(id=>acknowledged.current.add(id));api.acknowledgeMessages(chat.id,ids).then(onChanged).catch(()=>ids.forEach(id=>acknowledged.current.delete(id)));},{root:list.current,threshold:.6});
    list.current.querySelectorAll('[data-needs-read=yes]').forEach(node=>observer.observe(node));return()=>observer.disconnect();
  },[messages,results,direct,chat.id,onChanged]);
  useEffect(()=>{setInfo(current=>current?messages.find(message=>message.id===current.id)||current:null);},[messages]);
  const visible=(results??messages).filter(m=>!m.hiddenForMe&&(filter==='all'||(filter==='starred'?m.starred:m.pinned)));
  const pinned=messages.filter(m=>m.pinned&&!m.hiddenForMe&&!m.deletedAt);
  function update(message:Message){setMessages(values=>values.map(value=>value.id===message.id?message:value));setResults(values=>values?.map(value=>value.id===message.id?message:value)??null);if(info?.id===message.id)setInfo(message);onChanged();}
  function hide(id:number){setMessages(values=>values.map(value=>value.id===id?{...value,hiddenForMe:true}:value));setResults(values=>values?.filter(value=>value.id!==id)??null);if(info?.id===id)setInfo(null);if(reply?.id===id)setReply(null);onChanged();}
  async function earlier(){if(!messages.length)return;const scroll=list.current,oldHeight=scroll?.scrollHeight||0;try{const page=direct?await api.fetchDirectMessages(chat.id,messages[0].id):await api.fetchCirclePosts(chat.id,messages[0].id);setMessages(values=>mergeMessagePage(page,values));setHasEarlier(page.length===50);requestAnimationFrame(()=>{if(scroll)scroll.scrollTop+=scroll.scrollHeight-oldHeight;});}catch(e){setError((e as Error).message);}}
  async function send(){if(sending||(!draft.trim()&&!file)||!canPost)return;setSending(true);setError('');try{const value=direct?await api.sendDirectMessage(chat.id,draft,file||undefined,setProgress,reply?.id):await api.createCirclePost(chat.id,draft,file||undefined,reply?.id,setProgress);setMessages(values=>mergeMessagePage(values,[value]));setDraft('');if(input.current)input.current.style.height='36px';setFile(null);setReply(null);setEmojiOpen(false);onChanged();requestAnimationFrame(bottom);}catch(e){setError((e as Error).message);}finally{setSending(false);setProgress(null);input.current?.focus();}}
  function write(value:string){setDraft(value);if(Date.now()-lastTyping.current>3000){lastTyping.current=Date.now();void(direct?api.setDirectTyping(chat.id,!!value.trim()):api.setCircleTyping(chat.id,!!value.trim())).catch(()=>{});}}
  function quote(message:Message){setReply(message);input.current?.focus();}
  function openPrivate(message:Message,quoted:boolean){onOpenPerson({type:'DIRECT',id:authorId(message),name:author(message),draft:quoted?`Regarding your message in ${chat.name}:\n“${message.message||message.attachmentName||'Attachment'}”\n\n`:undefined});}
  async function download(message:Message){const blob=direct?await api.fetchDirectMessageAttachment(chat.id,message.id):await api.fetchCircleAttachment(chat.id,message.id);const url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=message.attachmentName||'attachment';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
  const preview=(message:Message)=>{const parent=messages.find(value=>value.id===parentId(message)&&!value.hiddenForMe);return parent?{name:parent.currentUserAuthor?'You':author(parent),text:parent.deletedAt?'Message deleted':parent.message||parent.attachmentName||'Attachment'}:'replyPreview' in message&&message.replyPreview?{name:'Reply',text:message.replyPreview}:null;};
  const bubble=(message:Message,copy=false)=>{const quoted=preview(message);return <>
    <strong className="chat-sender">{message.currentUserAuthor?'You':author(message)}</strong>
    {message.forwarded&&!message.deletedAt&&<small className="chat-forwarded">↪ Forwarded</small>}
    {quoted&&<blockquote className="chat-quote"><strong>{quoted.name}</strong><span>{quoted.text}</span></blockquote>}
    {message.deletedAt?<p className="chat-deleted">This message was deleted</p>:<><Attachment message={message} chat={chat}/>{message.message&&<p className="chat-message-text">{message.message}</p>}</>}
    <MessageTimestamp createdAt={message.createdAt} editedAt={message.editedAt} mine={message.currentUserAuthor&&direct} readAt={'readAt' in message?message.readAt:null} deliveredAt={'deliveredAt' in message?message.deliveredAt:null}/>
    {!copy&&Object.entries(message.reactions||{}).length>0&&<div className="chat-reaction-badges">{Object.entries(message.reactions).map(([emoji,count])=><span key={emoji}>{emoji} {count}</span>)}</div>}
  </>;};
  return <section className={`chat-thread-layout ${info?'with-info':''}`} aria-label={`Conversation with ${chat.name}`}>
    <div className="chat-thread"><header className="chat-thread-header"><button className="chat-back" aria-label="Back to chats" onClick={onBack}>‹</button><span className="chat-avatar">{chat.name.charAt(0)}</span><div><strong>{chat.name}</strong><small>{presence?.typingUsers.length?'Typing…':direct?(presence?.online?'Online':'Private conversation'):'Circle conversation'}</small></div><button aria-label="Search this conversation" aria-pressed={searchOpen} onClick={()=>setSearchOpen(value=>!value)}>⌕</button><details className="chat-thread-options"><summary aria-label="Conversation options">⋮</summary><div><button onClick={()=>setFilter('all')}>All messages</button><button onClick={()=>setFilter('starred')}>Starred messages</button><button onClick={()=>setFilter('pinned')}>Pinned messages</button><button onClick={()=>{setInfo(null);onBack();}}>Close chat</button></div></details></header>
    {searchOpen&&<div className="chat-search-within"><input type="search" aria-label="Search this conversation" autoFocus placeholder="Search in this chat" value={search} onChange={event=>setSearch(event.target.value)}/><button onClick={()=>{setSearch('');setSearchOpen(false);}}>Close</button></div>}
    {filter!=='all'&&<div className="chat-filter-notice">{filter==='starred'?'Starred':'Pinned'} in loaded history <button onClick={()=>setFilter('all')}>Show all</button></div>}
    {!!pinned.length&&<button className="chat-pinned-banner" onClick={()=>{setFilter('all');setSearch('');requestAnimationFrame(()=>document.getElementById(`chat-message-${pinned[0].id}`)?.scrollIntoView({block:'center'}));}}>⌖ <strong>{author(pinned[0])}</strong><span>{pinned[0].message||pinned[0].attachmentName}</span><small>Only you</small></button>}
    <div ref={list} className="chat-message-list" onScroll={()=>{if(nearBottom())setNewMessages(false);}}>
      {hasEarlier&&!search&&<button className="chat-load-earlier" onClick={()=>void earlier()}>Load earlier messages</button>}
      {loading?<p className="chat-thread-empty">Loading messages…</p>:!visible.length?<p className="chat-thread-empty">{search||filter!=='all'?'No matching messages.':'Start the conversation.'}</p>:visible.map((message,index)=><Fragment key={message.id}>
        {(index===0||chatDay(visible[index-1].createdAt)!==chatDay(message.createdAt))&&<div className="chat-date-divider"><span>{chatDay(message.createdAt)}</span></div>}
        <article id={`chat-message-${message.id}`} data-message-id={message.id} data-needs-read={direct&&!message.currentUserAuthor&&'readAt' in message&&!message.readAt?'yes':undefined} className={`chat-bubble ${message.currentUserAuthor?'mine':'received'}`}>
          {bubble(message)}
          <ChatMessageActions id={message.id} sourceType={chat.type} conversationId={chat.id} message={message.message} deleted={!!message.deletedAt} starred={!!message.starred} pinned={!!message.pinned} forwarded={!!message.forwarded} myReaction={message.myReaction} hideIndicators canDeleteForAll={message.canDeleteForAll&&Date.now()<Date.parse(message.createdAt)+86400000} info={null} onInfo={()=>setInfo(message)} onReply={canPost?()=>quote(message):undefined}
            onPrivateReply={!direct&&!message.currentUserAuthor?()=>openPrivate(message,true):undefined} onMessageAuthor={!direct&&!message.currentUserAuthor?()=>openPrivate(message,false):undefined}
            onFlags={async flags=>update(direct?await api.setMessageFlags(chat.id,message.id,flags):await api.setCircleMessageFlags(chat.id,message.id,flags))}
            onReact={async emoji=>update(direct?await api.reactDirectMessage(chat.id,message.id,emoji):await api.reactCirclePost(chat.id,message.id,emoji))}
            onEdit={message.currentUserAuthor?async()=>{const value=prompt('Edit message',message.message);if(value!==null)update(direct?await api.editDirectMessage(chat.id,message.id,value):await api.editCirclePost(chat.id,message.id,value));}:undefined}
            onDeleteForMe={async()=>{if(direct)await api.deleteDirectMessageForMe(chat.id,message.id);else await api.deleteCirclePostForMe(chat.id,message.id);hide(message.id);}}
            onDeleteForAll={async()=>update(direct?await api.deleteDirectMessage(chat.id,message.id):await api.deleteCirclePost(chat.id,message.id))}
            onDownload={message.attachmentUrl?()=>download(message):undefined}
            onReport={!message.currentUserAuthor?async()=>{const details=prompt('Why are you reporting this message?');if(details?.trim()){await api.reportContent({reportedUserId:authorId(message),entityType:direct?'DIRECT_MESSAGE':'CIRCLE_POST',entityId:message.id,reason:'OTHER',details});setError('Report submitted.');}}:undefined}/>
        </article>
      </Fragment>)}
    </div>
    {newMessages&&<button className="chat-jump-latest" aria-label="Jump to latest messages" onClick={bottom}>↓</button>}
    {error&&<div className="chat-inline-error" role="alert">{error}<button aria-label="Dismiss message" onClick={()=>setError('')}>×</button></div>}
    {canPost?<footer className="chat-composer">
      {reply&&<div className="chat-composer-reply"><div><strong>{reply.currentUserAuthor?'You':author(reply)}</strong><span>{reply.message||reply.attachmentName}</span></div><button aria-label="Cancel reply" onClick={()=>setReply(null)}>×</button></div>}
      {file&&<div className="chat-selected-file">{file.name}<button aria-label="Remove attachment" onClick={()=>setFile(null)}>×</button></div>}
      {emojiOpen&&<div className="chat-composer-emoji">{['😀','😊','❤️','👍','🙏','🎉','😂','👋'].map(emoji=><button key={emoji} aria-label={`Insert ${emoji}`} onClick={()=>{setDraft(value=>value+emoji);input.current?.focus();}}>{emoji}</button>)}</div>}
      <div className="chat-compose-row"><label className="chat-attach" title="Attach a file"><span aria-hidden="true">＋</span><input aria-label="Attach file" type="file" accept={attachmentAccept} disabled={sending} onChange={event=>{const value=event.target.files?.[0];if(value&&value.size>25*1024*1024)setError('Choose a file smaller than 25 MB.');else setFile(value||null);event.target.value='';}}/></label><button aria-label="Emoji" aria-expanded={emojiOpen} onClick={()=>setEmojiOpen(value=>!value)}>☺</button><textarea ref={input} rows={1} aria-label="Message text" placeholder="Type a message" value={draft} maxLength={4000} disabled={sending} onChange={event=>{write(event.target.value);event.target.style.height='auto';event.target.style.height=`${Math.min(120,event.target.scrollHeight)}px`;}} onKeyDown={event=>{if(event.key==='Enter'&&!event.shiftKey&&!event.nativeEvent.isComposing&&!window.matchMedia('(pointer:coarse)').matches){event.preventDefault();void send();}}}/><button className="chat-send" aria-label="Send message" disabled={sending||(!draft.trim()&&!file)} onClick={()=>void send()}>{sending?'…':'➤'}</button></div>{progress!==null&&<progress max="100" value={progress} aria-label="Upload progress"/>}
    </footer>:<div className="chat-posting-restricted">Only circle admins can send messages.</div>}
    </div>
    {info&&<aside className="chat-information" aria-label="Message info"><header><button aria-label="Close message info" onClick={()=>setInfo(null)}>×</button><h2>Message info</h2></header><div className={`chat-info-preview chat-bubble ${info.currentUserAuthor?'mine':''}`}>{bubble(info,true)}</div><dl><dt>Sent</dt><dd>{new Date(info.createdAt).toLocaleString()}</dd>{direct?<><dt>Delivered</dt><dd>{'deliveredAt' in info&&info.deliveredAt?new Date(info.deliveredAt).toLocaleString():'Not confirmed'}</dd><dt>Read</dt><dd>{'readAt' in info&&info.readAt?new Date(info.readAt).toLocaleString():'Not confirmed or receipts disabled'}</dd></>:<><dt>Read</dt><dd>{'readCount' in info?info.readCount:0} members</dd></>}</dl><small>Stars and pins are private to you.</small></aside>}
  </section>;
}
