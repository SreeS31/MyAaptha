'use client';
import ChatMessageActions from './ChatMessageActions';
import {DirectMessage,deleteDirectMessageForMe,setMessageFlags,editDirectMessage,deleteDirectMessage,reactDirectMessage,fetchDirectMessageAttachment} from '../lib/api';
export default function DirectMessageActions({item,other,onUpdated,onReply,onRemoved}:{item:DirectMessage;other:number;onUpdated:(item:DirectMessage)=>void;onReply:()=>void;onRemoved:()=>void}){
  return <ChatMessageActions id={item.id} sourceType="DIRECT" conversationId={other} message={item.message} deleted={!!item.deletedAt} starred={item.starred} pinned={item.pinned} forwarded={item.forwarded} myReaction={item.myReaction} canDeleteForAll={item.canDeleteForAll&&Date.now()<Date.parse(item.createdAt)+86400000}
    onReply={onReply} onFlags={async flags=>onUpdated(await setMessageFlags(other,item.id,flags))} onReact={async emoji=>onUpdated(await reactDirectMessage(other,item.id,emoji))}
    onEdit={item.currentUserAuthor?async()=>{const value=prompt('Edit message',item.message);if(value!==null)onUpdated(await editDirectMessage(other,item.id,value));}:undefined}
    onDeleteForMe={async()=>{await deleteDirectMessageForMe(other,item.id);onRemoved();}} onDeleteForAll={async()=>onUpdated(await deleteDirectMessage(other,item.id))}
    onDownload={item.attachmentUrl?async()=>{const blob=await fetchDirectMessageAttachment(other,item.id);const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download=item.attachmentName||'attachment';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}:undefined}
    info={<dl className="message-receipts"><div><dt>Sent</dt><dd>{new Date(item.createdAt).toLocaleString()}</dd></div><div><dt>Delivered</dt><dd>{item.deliveredAt?new Date(item.deliveredAt).toLocaleString():'Not confirmed'}</dd></div><div><dt>Read</dt><dd>{item.readAt?new Date(item.readAt).toLocaleString():'Not confirmed or receipts disabled'}</dd></div></dl>}/>;
}
