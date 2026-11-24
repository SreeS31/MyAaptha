import {authenticatedRequest as request} from './api';
export type Highlight={key:string;memberId:number|null;contactId:number|null;name:string;connectedCalls:number;lastCall:string|null;starred:boolean;hidden:boolean};
export const peopleHighlights=(view='frequent',afterId=0)=>request<{enabled:boolean;days:number;items:Highlight[];nextCursor:number|null}>('/api/people/highlights?'+new URLSearchParams({view,afterId:String(afterId)}));
export const chooseHighlight=(person:Pick<Highlight,'memberId'|'contactId'>,starred:boolean,hidden=false)=>request<void>('/api/people/highlights',{method:'POST',body:JSON.stringify({memberId:person.memberId,contactId:person.contactId,starred,hidden})});
export const highlightPreferences=(enabled:boolean)=>request<{enabled:boolean}>('/api/people/highlights/preferences',{method:'POST',body:JSON.stringify({enabled})});
