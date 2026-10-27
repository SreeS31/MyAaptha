export function chatTime(value:string){return new Date(value).toLocaleTimeString([], {hour:'numeric',minute:'2-digit'});}
export function chatDay(value:string){const date=new Date(value),today=new Date(),yesterday=new Date();yesterday.setDate(today.getDate()-1);return date.toDateString()===today.toDateString()?'Today':date.toDateString()===yesterday.toDateString()?'Yesterday':date.toLocaleDateString([], {day:'numeric',month:'short',year:date.getFullYear()!==today.getFullYear()?'numeric':undefined});}
export default function MessageTimestamp({createdAt,editedAt,mine,readAt,deliveredAt}:{createdAt:string;editedAt?:string|null;mine:boolean;readAt?:string|null;deliveredAt?:string|null}){
  const status=readAt?'Read':deliveredAt?'Delivered':'Sent';
  return <footer className="chat-message-meta">{editedAt&&<span>edited</span>}<time dateTime={createdAt} title={new Date(createdAt).toLocaleString()}>{chatTime(createdAt)}</time>{mine&&<span className={readAt?'chat-ticks read':'chat-ticks'} role="img" aria-label={status} title={status}>{deliveredAt||readAt?'✓✓':'✓'}</span>}</footer>;
}
