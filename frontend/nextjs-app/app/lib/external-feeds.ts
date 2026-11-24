import {authenticatedRequest as request,SocialPost} from './api';
export type ExternalSource={id:number;advisorId:number;title:string;url:string;lastSuccess:string|null;error:string|null;enabled:boolean};
export type ExternalItem={id:number;sourceId:number;sourceName:string;title:string;summary:string;url:string;publishedAt:string|null;saved:boolean;liked:boolean};
export const externalSources=(afterId=0)=>request<{items:ExternalSource[];nextCursor:number|null}>('/api/advisors/external/sources?afterId='+afterId);
export function feedAddress(raw:string){const value=raw.trim();const match=value.match(/^(UC[\w-]{22})$/)||value.match(/^https:\/\/(?:www\.)?youtube\.com\/channel\/(UC[\w-]{22})\/?$/);return match?'https://www.youtube.com/feeds/videos.xml?channel_id='+match[1]:value;}
export const connectExternalFeed=(advisorId:number,url:string)=>request<ExternalSource>('/api/advisors/external/sources',{method:'POST',body:JSON.stringify({advisorId,url:feedAddress(url),consent:true})});
export const refreshExternalFeed=(id:number)=>request<ExternalSource>(`/api/advisors/external/sources/${id}/refresh`,{method:'POST',body:'{}'});
export const removeExternalFeed=(id:number)=>request<void>(`/api/advisors/external/sources/${id}/delete`,{method:'POST',body:'{}'});
export const externalItems=(category='ALL',saved=false,beforeId?:number)=>request<{items:ExternalItem[];nextCursor:number|null}>('/api/advisors/external?'+new URLSearchParams({category,saved:String(saved),...(beforeId?{beforeId:String(beforeId)}:{})}));
export const externalFlags=(item:ExternalItem,saved=item.saved,liked=item.liked)=>request<ExternalItem>(`/api/advisors/external/items/${item.id}`,{method:'POST',body:JSON.stringify({saved,liked})});
export const repostExternalLink=(id:number)=>request<SocialPost>(`/api/advisors/external/items/${id}/repost`,{method:'POST',body:JSON.stringify({confirm:true})});

export const externalSourceState=(id:number,enabled:boolean)=>request<ExternalSource>(`/api/advisors/external/sources/${id}/state`,{method:'POST',body:JSON.stringify({enabled})});
