import {authenticatedRequest as request} from './api';
export type TreeNode={key:string;contactId:number|null;name:string;relation:string;parentKey:string|null;gender?:'MALE'|'FEMALE'|'OTHER'|'UNSPECIFIED'|null};
export type ReviewedTree={id:number|null;sourceKey:string|null;name:string;reason:string;confidence:string;nodes:TreeNode[];version:number};
export type TreeCard={id:number|null;key:string|null;name:string;reason:string;confidence:string;count:number;preview:TreeNode[];version:number};
export type TreeSuggestions={scannedContacts:number;totalSuggestions:number;dismissedCount:number;smallGroupsSkipped:number;items:TreeCard[];nextOffset:number|null};
export const suggestTrees=(offset=0)=>request<TreeSuggestions>('/api/relationship-trees/suggestions?offset='+offset);
export const suggestedTree=(key:string)=>request<ReviewedTree>('/api/relationship-trees/suggestions/'+key);
export const savedTrees=(afterId=0)=>request<{items:TreeCard[];nextCursor:number|null}>('/api/relationship-trees?afterId='+afterId);
export const savedTree=(id:number)=>request<ReviewedTree>('/api/relationship-trees/'+id);
export type TreePersonInfo={key:string;name:string;relation:string;gender:string|null;phones:string[];emails:string[];organization:string;groups:string[];contactAvailable:boolean};
export const treePersonInfo=(id:number,key:string)=>request<TreePersonInfo>(`/api/relationship-trees/${id}/person?key=${encodeURIComponent(key)}`);
export const saveTree=(tree:ReviewedTree)=>request<ReviewedTree>(`/api/relationship-trees${tree.id?`/${tree.id}/update`:''}`,{method:'POST',body:JSON.stringify({name:tree.name,sourceKey:tree.sourceKey,reason:tree.reason,nodes:tree.nodes,version:tree.version,reviewed:true})});
export const deleteTree=(id:number)=>request<void>(`/api/relationship-trees/${id}/delete`,{method:'POST',body:'{}'});
export const dismissTree=(key:string)=>request<void>('/api/relationship-trees/suggestions/dismiss',{method:'POST',body:JSON.stringify({key})});
export const restoreTrees=()=>request<void>('/api/relationship-trees/suggestions/restore',{method:'POST',body:'{}'});
export const treeContacts=(q='',afterId=0)=>request<{items:{id:number;name:string}[];nextCursor:number|null;total:number}>('/api/relationship-trees/contacts?'+new URLSearchParams({q,afterId:String(afterId)}));

export const treeMessageTarget=(id:number,key:string)=>request<{userId:number|null;name:string|null;contactId?:number|null}>(`/api/relationship-trees/${id}/message-target?key=${encodeURIComponent(key)}`);
