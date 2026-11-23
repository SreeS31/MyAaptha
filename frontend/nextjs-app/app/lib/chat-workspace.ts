import {authenticatedRequest as request} from './api';
export type ChatOptions={favourite:boolean;archived:boolean;mutedUntil:string|null;theme:string;listName:string;disappearingSeconds:number;canManage:boolean;creator:boolean;solo:boolean};
export type OptionChange=Partial<Pick<ChatOptions,'favourite'|'archived'|'theme'|'listName'|'disappearingSeconds'>>&{muteSeconds?:number};
const path=(kind:string,id:number)=>`/api/network/chats/workspace/${kind}/${id}`;
export const getChatOptions=(kind:string,id:number)=>request<ChatOptions>(path(kind,id));
export const saveChatOptions=(kind:string,id:number,value:OptionChange)=>request<ChatOptions>(path(kind,id),{method:'PUT',body:JSON.stringify(value)});
export const clearChat=(kind:string,id:number)=>request<void>(path(kind,id)+'/history',{method:'DELETE'});
export const exitCircle=(id:number,successorId?:number,deleteEmptyCircle=false)=>request<void>(path('CIRCLE',id)+'/exit',{method:'POST',body:JSON.stringify({successorId,deleteEmptyCircle})});
export async function exportChat(kind:string,id:number,name:string){
 const rows:Record<string,unknown>[]=[];let before=Number.MAX_SAFE_INTEGER;
 for(;;){const page=await request<Record<string,unknown>[]>(path(kind,id)+`/export?before=${before}`);rows.push(...page);if(page.length<500)break;const next=Math.min(...page.map(row=>Number(row.id)));if(next>=before)throw new Error('Export pagination did not advance');before=next;}
 const blob=new Blob([JSON.stringify({name,exportedAt:new Date().toISOString(),messages:rows.reverse()},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='MyAaptha-chat.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}

export type ChatSummary={kind:'DIRECT'|'CIRCLE';targetId:number;favourite:boolean;archived:boolean;listName:string};
export const allChatOptions=()=>request<ChatSummary[]>('/api/network/chats/workspace');
