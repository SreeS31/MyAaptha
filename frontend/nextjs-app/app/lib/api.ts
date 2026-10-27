import {validateUploadForm as validateUploadFiles} from './upload-security';
import {chooseUploadRetention} from './upload-retention';
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ||
  (process.env.NODE_ENV === 'production' ? '' : 'http://localhost:8080');
const AUTH_SESSION_KEY = 'myaaptha.web-session.metadata';

export type AddressContact = import('./contact-import').AddressContactInput & {id:number;source:string;relationshipId:number|null;circleIds:number[]};
export type AddressBookPage = {items:AddressContact[];nextCursor:number|null;total:number};
export const fetchAddressBook=(q='',afterId=0,circleId?:number)=>authenticatedRequest<AddressBookPage>(`/api/address-book?q=${encodeURIComponent(q)}&afterId=${afterId}&limit=50${circleId?`&circleId=${circleId}`:''}`);
export const importAddressBook=(contacts:import('./contact-import').AddressContactInput[],source:string,organize=false)=>authenticatedRequest<{added:number;updated:number;unchanged:number;total:number;organizationMessage:string}>('/api/address-book/import',{method:'POST',body:JSON.stringify({consent:true,contacts,source,organize})});
export const importReviewedAddressBook=(contacts:import('./contact-import').ReviewedContact[],source:string,organize:boolean)=>authenticatedRequest<{added:number;updated:number;unchanged:number;skipped:number;total:number;organizationMessage:string}>('/api/address-book/import-reviewed',{method:'POST',body:JSON.stringify({consent:true,source,contacts:contacts.map(({selected,circleNames,...contact})=>({contact,circleNames:organize?circleNames.map(n=>n.trim()).filter(Boolean):[]}))})});
export const deleteAddressContact=(id:number)=>authenticatedRequest<void>(`/api/address-book/${id}`,{method:'DELETE'});
export const clearAddressBook=()=>authenticatedRequest<void>('/api/address-book?confirm=true',{method:'DELETE'});
export const relateAddressContact=(id:number,relationship:string,phone:string|null)=>authenticatedRequest<AddressContact>(`/api/address-book/${id}/relation`,{method:'POST',body:JSON.stringify({consent:true,relationship,phone})});
export const addressBookProviders=()=>authenticatedRequest<{google:boolean;microsoft:boolean}>('/api/address-book/providers');
export const connectAddressBook=(email:string,provider:string,organize=false)=>authenticatedRequest<{authorizationUrl:string;resultKey:string}>('/api/address-book/oauth/start',{method:'POST',body:JSON.stringify({consent:true,email,provider,organize})});
export type AddressBookOAuthResult={contacts?:import('./contact-import').AddressContactInput[];status:string;message:string;added?:number;updated?:number;unchanged?:number};
export const addressBookOAuthResult=(key:string)=>authenticatedRequest<AddressBookOAuthResult>(`/api/address-book/oauth/results/${encodeURIComponent(key)}`);

export type AuthSession = {
  expiresIn: number;
};

type StoredAuthSession = AuthSession & {
  receivedAtEpochMs: number;
  expiresAtEpochMs: number;
};

export type SessionTiming = {
  receivedAtEpochMs: number;
  expiresAtEpochMs: number;
  secondsRemaining: number;
  isExpired: boolean;
};

export type SessionProfile = {
  id: number;
  username: string;
  email: string;
  phoneNumber: string;
  role: string;
};

export type UserProfile = Record<string, string | string[] | null> & { phoneNumber: string; photos: string[]; profilePhoto: string | null };
export type PersonRecord = { nickname:string|null; contactPhone:string|null; contactEmail:string|null; address:string|null; city:string|null; country:string|null; occupation:string|null; dateOfBirth:string|null; marriageDate:string|null; dateOfDeath:string|null; importantDates:string|null; notes:string|null };
export type PersonMemory = { id:number; title:string|null; note:string|null; mediaUrl:string|null; mediaName:string|null; mediaType:string|null; mediaSize:number|null; createdAt:string };
export type PersonProfile = { id:number; displayName:string; profilePhoto:string|null; location:string|null; gender:string|null; bio:string|null; employer:string|null; jobTitle:string|null; institution:string|null; managedCategory:string|null; dateOfBirth:string|null; dateOfDeath:string|null; managedBiography:string|null; managedByMe:boolean; privateRecord:PersonRecord; memories:PersonMemory[] };

export async function fetchUserProfile() { return authenticatedRequest<UserProfile>('/api/profile/me'); }
export async function saveUserProfile(profile: UserProfile) { return authenticatedRequest<UserProfile>('/api/profile/me', { method: 'PUT', body: JSON.stringify(profile) }); }
export async function uploadProfilePhoto(file: File) { const body=new FormData();body.append('file',file);return authenticatedRequest<UserProfile>('/api/profile/me/photo',{method:'POST',body}); }
export async function removeProfilePhoto() { return authenticatedRequest<UserProfile>('/api/profile/me/photo',{method:'DELETE'}); }
export async function uploadGalleryPhoto(file: File) { const body=new FormData();body.append('file',file);return authenticatedRequest<UserProfile>('/api/profile/me/photos',{method:'POST',body}); }
export async function removeGalleryPhoto(index: number) { return authenticatedRequest<UserProfile>(`/api/profile/me/photos/${index}`,{method:'DELETE'}); }
export async function fetchPersonProfile(id:number){return authenticatedRequest<PersonProfile>(`/api/people/${id}/profile`);}
export async function uploadPersonProfilePhoto(id:number,file:File){if(file.size>5*1024*1024)throw new Error('Profile photo must be 5 MB or smaller.');if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Choose a JPG, PNG, or WebP photo.');const body=new FormData();body.append('file',file);return authenticatedRequest<PersonProfile>(`/api/people/${id}/photo`,{method:'POST',body});}
export async function savePersonRecord(id:number,value:PersonRecord){return authenticatedRequest<PersonProfile>(`/api/people/${id}/record`,{method:'PUT',body:JSON.stringify(value)});}
export async function addPersonMemory(id:number,title:string,note:string,file?:File){
  if(file&&file.size>25*1024*1024)throw new Error('Attachment must be 25 MB or smaller.');
  const body=new FormData();if(title)body.append('title',title);if(note)body.append('note',note);if(file)body.append('file',file);
  const upload=(mayRefresh:boolean):Promise<PersonMemory>=>new Promise<PersonMemory>((resolve,reject)=>{
    const session=getStoredAuthSession();const request=new XMLHttpRequest();request.open('POST',`${API_BASE_URL}/api/people/${id}/memories`);request.withCredentials=true;request.setRequestHeader('X-MyAaptha-Web','1');
    const announce=(progress:number,status:'uploading'|'processing'|'complete'|'error',message:string)=>window.dispatchEvent(new CustomEvent('myaaptha:upload-progress',{detail:{progress,status,message,fileName:file?.name||'Memory'}}));
    announce(0,'uploading','Preparing upload…');request.upload.onprogress=event=>{if(event.lengthComputable)announce(Math.min(99,Math.round(event.loaded/event.total*100)),'uploading','Uploading memory…');};request.upload.onload=()=>announce(99,'processing','Upload received. Saving memory…');
    request.onerror=()=>{announce(0,'error','Upload failed');reject(new ApiError(0,'The upload connection failed. If this is a cloud file, download it locally and try again.'));};
    request.onload=async()=>{if(request.status>=200&&request.status<300){announce(100,'complete','Upload completed');try{resolve(JSON.parse(request.responseText) as PersonMemory);window.setTimeout(()=>{const gallery=document.querySelector<HTMLDetailsElement>('.memory-gallery-disclosure');if(gallery){gallery.open=true;gallery.scrollIntoView({behavior:'smooth',block:'start'});}},700);}catch{reject(new ApiError(request.status,'The upload completed but its response could not be read.'));}return;}if(request.status===401&&mayRefresh){announce(0,'processing','Refreshing session…');try{await refreshSessionOrThrow();resolve(await upload(false));}catch{clearAuthSession();announce(0,'error','Session expired');reject(new ApiError(401,'Session expired. Please sign in again.'));}return;}let message=`Request failed: ${request.status}`;try{const value=JSON.parse(request.responseText) as {message?:string;error?:string};message=value.message||value.error||message;}catch{}announce(0,'error',message);reject(new ApiError(request.status,message));};void validateUploadForm(body).then(()=>{request.timeout=90000;request.ontimeout=()=>reject(new ApiError(0,'Upload timed out. Please retry.'));request.send(body);}).catch(reject);
  });
  return upload(true);
}
export async function deletePersonMemory(personId:number,memoryId:number){return authenticatedRequest<void>(`/api/people/${personId}/memories/${memoryId}`,{method:'DELETE'});}
export async function fetchPersonMemoryMedia(path:string){return authenticatedRequest<Blob>(path,{responseType:'blob'});}

type RequestOptions = RequestInit & {
  skipAuth?: boolean;
  responseType?: 'blob';
};

export class ApiError extends Error {
  status: number;

  constructor(status: number, message?: string) {
    super(message ?? `Request failed: ${status}`);
    this.status = status;
  }
}

export type HelpReply = { answer: string; mode: 'AI' | 'HELP' | 'CACHE'; exchangeId?:string; tier?:'BASE'|'ENHANCED'; model?:string; notice: string; sources: {id:string; title:string; path:string; content:string}[] };
export function fetchHelpStatus() { return authenticatedRequest<{aiConfigured:boolean;enhancedEnabled:boolean;canManage:boolean;baseModel:string;enhancedModel:string;questions:string[]}>('/api/ai/help'); }
export function askHelp(message:string, history:{role:'user'|'assistant';content:string}[], useAi:boolean, retryOf?:string) {
  return authenticatedRequest<HelpReply>('/api/ai/help/chat',{method:'POST',body:JSON.stringify({message,history,useAi,retryOf})});
}

function getStoredAuthSession(): StoredAuthSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  window.localStorage.removeItem('myaaptha.auth.session');
  const raw = window.localStorage.getItem(AUTH_SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as Partial<StoredAuthSession>;
    if (!parsed.expiresIn) {
      window.localStorage.removeItem(AUTH_SESSION_KEY);
      return null;
    }

    if (typeof parsed.receivedAtEpochMs === 'number' && typeof parsed.expiresAtEpochMs === 'number') {
      return parsed as StoredAuthSession;
    }

    const migratedSession: StoredAuthSession = {
      expiresIn: parsed.expiresIn,
      receivedAtEpochMs: Date.now(),
      expiresAtEpochMs: Date.now() + (parsed.expiresIn * 1000),
    };
    window.localStorage.setItem(AUTH_SESSION_KEY, JSON.stringify(migratedSession));
    return migratedSession;
  } catch {
    window.localStorage.removeItem(AUTH_SESSION_KEY);
    return null;
  }
}

function setStoredAuthSession(session: AuthSession) {
  if (typeof window === 'undefined') {
    return;
  }
  const receivedAtEpochMs = Date.now();
  const storedSession: StoredAuthSession = {
    expiresIn: session.expiresIn,
    receivedAtEpochMs,
    expiresAtEpochMs: receivedAtEpochMs + (session.expiresIn * 1000),
  };

  window.localStorage.setItem(AUTH_SESSION_KEY, JSON.stringify(storedSession));
}

export function clearAuthSession() {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.removeItem(AUTH_SESSION_KEY);
}

export function hasAuthSession() {
  const session = getStoredAuthSession();
  return !!session?.expiresIn;
}

export function getSessionTiming(): SessionTiming | null {
  const session = getStoredAuthSession();
  if (!session) {
    return null;
  }

  const secondsRemaining = Math.max(0, Math.floor((session.expiresAtEpochMs - Date.now()) / 1000));
  return {
    receivedAtEpochMs: session.receivedAtEpochMs,
    expiresAtEpochMs: session.expiresAtEpochMs,
    secondsRemaining,
    isExpired: secondsRemaining <= 0,
  };
}

export function isUnauthorizedError(error: unknown): boolean {
  return error instanceof ApiError && error.status === 401;
}

async function request<T>(path: string, init?: RequestOptions): Promise<T> {
  if(init?.body instanceof FormData){if(path==='/api/health/reports/analyze')await validateUploadFiles(init.body);else await validateUploadForm(init.body);}
  const session = getStoredAuthSession();
  const headers: Record<string, string> = {
    ...(init?.body instanceof FormData ? {} : { 'Content-Type': 'application/json' }),
    ...(init?.headers as Record<string, string> || {}),
  };

  headers['X-MyAaptha-Web']='1';

  let response: Response;
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 12000);
  if (init?.signal) init.signal.addEventListener('abort', () => controller.abort(), { once: true });
  try {
    response = await fetch(`${API_BASE_URL}${path}`, { ...init, headers, credentials:'include', signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) throw new ApiError(0, 'The server took too long to respond. Try again or sign out and sign in again.');
    if (init?.body instanceof FormData) throw new ApiError(0, 'The browser could not read or upload this file. If it is stored in OneDrive or another cloud folder, download it to this device or start the cloud provider, then choose it again.');
    throw error;
  } finally {
    window.clearTimeout(timeout);
  }

  if (!response.ok) {
    const errorBody = await response.text();
    let message = `Request failed: ${response.status}`;

    if (errorBody) {
      try {
        const parsed = JSON.parse(errorBody) as { message?: string; error?: string };
        message = parsed.message || parsed.error || message;
      } catch {
        message = errorBody;
      }
    }

    throw new ApiError(response.status, message);
  }

  if (response.status === 204) {
    return undefined as T;
  }
  if (init?.responseType === 'blob') return response.blob() as Promise<T>;

  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json() as Promise<T>;
  }

  return response.text() as Promise<T>;
}

async function performSessionRefresh() {
  const currentSession = getStoredAuthSession();
  if (!currentSession?.expiresIn) {
    throw new ApiError(401, 'Missing refresh token');
  }

  const refreshedSession = await request<AuthSession>('/api/web-auth/refresh', {
    method: 'POST',
    body: '{}',
    skipAuth: true,
  });
  setStoredAuthSession(refreshedSession);
  return refreshedSession;
}

let refreshInFlight:Promise<AuthSession>|undefined;
async function refreshSessionOrThrow(){
  if(!refreshInFlight){
    const observed=getStoredAuthSession()?.receivedAtEpochMs;
    const action=async()=>{const current=getStoredAuthSession();if(current&&current.receivedAtEpochMs!==observed)return current;return performSessionRefresh();};
    refreshInFlight=(typeof navigator!=='undefined'&&navigator.locks?navigator.locks.request('myaaptha-session-refresh',action):action()).finally(()=>{refreshInFlight=undefined;});
  }
  return refreshInFlight;
}

export async function refreshSession() {
  return refreshSessionOrThrow();
}

async function authenticatedRequest<T>(path: string, init?: RequestOptions): Promise<T> {
  try {
    return await request<T>(path, init);
  } catch (error) {
    if (!isUnauthorizedError(error)) {
      throw error;
    }

    try {
      await refreshSessionOrThrow();
      return await request<T>(path, init);
    } catch {
      clearAuthSession();
      throw new ApiError(401, 'Session expired');
    }
  }
}

export async function login(identifier: string, password: string,otpCode?:string) {
  const session = await request<AuthSession>('/api/web-auth/login', {
    method: 'POST',
    body: JSON.stringify({ identifier, password,otpCode:otpCode||undefined }),
    skipAuth: true,
  });
  setStoredAuthSession(session);
  return session;
}

export async function fetchAuthHealth() {
  return request<string>('/api/auth/health', {
    method: 'GET',
    skipAuth: true,
  });
}

export async function fetchSessionProfile() {
  return authenticatedRequest<SessionProfile>('/api/auth/me');
}

export function logout() {
  const session = getStoredAuthSession();
  clearAuthSession();
  if (session?.expiresIn) {
    void request<void>('/api/web-auth/logout', {
      method: 'POST',
      body: '{}',
      skipAuth: true,
    }).catch(() => {});
  }
}

export async function revokeSession() {
  const session = getStoredAuthSession();
  if (!session?.expiresIn) {
    clearAuthSession();
    return;
  }

  try {
    await request<void>('/api/web-auth/revoke', {
      method: 'POST',
      body: '{}',
      skipAuth: true,
    });
  } finally {
    clearAuthSession();
  }
}

export async function fetchUsers() {
  return authenticatedRequest<any[]>('/api/users');
}

export async function createUser(payload: { username: string; email?: string; phoneNumber: string; password: string; verificationCode?:string; firstName?: string; surname?: string; location?: string }) {
  return request<any>('/api/users', {
    method: 'POST',
    body: JSON.stringify(payload),
    skipAuth: true,
  });
}

export async function updateUser(id: number, payload: { username: string; email?: string; phoneNumber: string; password?: string }) {
  return authenticatedRequest<any>(`/api/users/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export type NetworkPerson = { id: number; firstName?: string; surname?: string; displayName: string; phoneNumber?: string | null; location?: string; accountStatus: 'ACTIVE' | 'INVITED' | 'MANAGED'; profilePhoto?: string | null; identityType?: 'ACCOUNT' | 'MANAGED'; managedCategory?: 'CHILD' | 'MEMORIAL' | 'OTHER' | null; claimStatus?: 'NONE' | 'NOT_CLAIMABLE' | 'GUARDIAN_APPROVAL_REQUIRED'; gender?: string | null };
export type VisibilityScope = 'PUBLIC' | 'FRIENDS' | 'RELATIVES' | 'COLLEAGUES';
export type NetworkRelationship = { id: number; type: string; visibilityScope: VisibilityScope; visibilityCompany?: string | null; contactPhone?: string | null; contactEmail?: string | null; relativeToUserId?: number | null; milestoneDate?: string | null; dateOfBirth?: string | null; dateOfDeath?: string | null; person: NetworkPerson };
export type NetworkCircleMember = { person: NetworkPerson; admin: boolean; creator: boolean };
export type CirclePostingPermission = 'ALL_MEMBERS' | 'ADMINS_ONLY';
export type NetworkCircle = { id: number; name: string; description: string; members: NetworkCircleMember[]; ownerName: string; ownerPhoto?: string | null; ownedByCurrentUser: boolean; currentUserAdmin: boolean; postingPermission: CirclePostingPermission; currentUserCanPost: boolean;};
export type CirclePost = { id:number; circleId:number; parentPostId?:number|null; authorId:number; authorName:string; authorPhoto?:string|null; message:string; attachmentUrl?:string|null; attachmentName?:string|null; attachmentType?:string|null; attachmentSize?:number|null; createdAt:string; editedAt?:string|null; deletedAt?:string|null; reactions:Record<string,number>; myReaction?:string|null; readCount:number; currentUserAuthor:boolean; canDeleteForAll:boolean; hiddenForMe?:boolean; starred?:boolean;pinned?:boolean;forwarded?:boolean };
export type DirectMessage = { id:number; senderId:number; recipientId:number; senderName:string; senderPhoto?:string|null; message:string; attachmentUrl?:string|null; attachmentName?:string|null; attachmentType?:string|null; attachmentSize?:number|null; createdAt:string; deliveredAt?:string|null; readAt?:string|null; replyToMessageId?:number|null; replyPreview?:string|null; editedAt?:string|null; deletedAt?:string|null; reactions:Record<string,number>; myReaction?:string|null; currentUserAuthor:boolean; starred:boolean; pinned:boolean; forwarded:boolean; canDeleteForAll:boolean; hiddenForMe?:boolean };
export type DirectConversation = { archived:boolean; muted:boolean; markedUnread:boolean; pinned:boolean; userId:number; displayName:string; profilePhoto?:string|null; lastMessage:string; lastMessageAt:string; unreadCount:number };
export type DirectCall = { id:number; callerId:number; recipientId:number; callerName:string; callerPhoto?:string|null; recipientName:string; recipientPhoto?:string|null; callType:'AUDIO'|'VIDEO'; status:'RINGING'|'ACCEPTED'|'REJECTED'|'ENDED'; offerSdp:string; answerSdp?:string|null; createdAt:string; updatedAt:string; currentUserCaller:boolean };
export type BroadcastAudienceType = 'HORIZONTAL' | 'VERTICAL' | 'LOCATION';
export type BroadcastRecipient = { userId:number; displayName:string; relationship:string; location?:string|null; profilePhoto?:string|null };
export type BroadcastAudience = { audienceType:BroadcastAudienceType; anchorUserId?:number|null; locationQuery?:string|null; recipients:BroadcastRecipient[]; excludedCount:number };
export type BroadcastResult = { broadcastId:number; audienceType:BroadcastAudienceType; deliveredCount:number; failedCount:number; failures:string[]; createdAt:string };
export type ImportedContact = { contact_key:string; display_name:string; phones:string[]; emails:string[]; organization:string; job_title:string; labels:string[] };
export type ContactSuggestion = { contact_key:string; display_name:string; phone?:string|null; email?:string|null; suggested_relationship:string; suggested_circles:string[]; confidence:number; reasons:string[]; requires_review:boolean; selected?:boolean };
export type ContactOrganizerResult = { peopleAdded:number; circleMembershipsAdded:number; skipped:string[] };
export type SocialComment = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; message:string; createdAt:string; mine:boolean };
export type SocialPost = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; caption:string; audience:'PRIVATE'|'PUBLIC'|'FRIENDS'|'RELATIVES'|'RELATIONSHIPS'|'CIRCLE'; circleId?:number|null; mediaUrl?:string|null; mediaName?:string|null; mediaType?:string|null; mediaSize?:number|null; likeCount:number; commentCount:number; likedByMe:boolean; savedByMe:boolean; mine:boolean; createdAt:string; updatedAt:string; comments:SocialComment[];reactions?:Record<string,number>;myReaction?:string|null;pinned?:boolean };
export type SocialStory = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; caption:string; audience:'PUBLIC'|'RELATIONSHIPS'; mediaUrl:string; mediaType:string; createdAt:string; expiresAt:string; viewCount:number; viewedByMe:boolean; mine:boolean };
export type BlockedUser = { userId:number; displayName:string; profilePhoto?:string|null; blockedAt:string };
export type AppNotification = { id:number; type:string; title:string; body:string; actionUrl?:string|null; entityType?:string|null; entityId?:number|null; readAt?:string|null; createdAt:string };
export type PresenceStatus = { online:boolean; lastActiveAt?:string|null; typingUsers:{userId:number;displayName:string}[] };
export type NotificationPreferences = { emailEnabled:boolean; smsEnabled:boolean; pushEnabled:boolean; messagesEnabled:boolean; circlesEnabled:boolean; relationshipsEnabled:boolean; callsEnabled:boolean; invitationsEnabled:boolean; socialEnabled:boolean };
export type TrustedPerson = { userId:number; displayName:string; profilePhoto?:string|null; kind:'STAR'|'ROLE_MODEL'; followerCount:number; addedAt:string };
export type EmergencyRequest = { id:number; ownerUserId:number; ownerName:string; requesterUserId:number; requesterName:string; reason:string; status:'PENDING'|'APPROVED'|'REJECTED'|'EXPIRED'; approvals:number; requiredApprovals:number; createdAt:string; expiresAt:string; grantedUntil?:string|null; canDecide?:boolean; canViewDocuments?:boolean };
export type EmergencyDocument = { id:number; caption:string; mediaName:string; mediaType:string; mediaSize:number; mediaUrl:string; createdAt:string };
export async function fetchTrustedPeople(kind:'STAR'|'ROLE_MODEL'){return authenticatedRequest<TrustedPerson[]>(`/api/trust/people?kind=${kind}`);}
export async function fetchInboundTrustedPeople(kind:'STAR'|'ROLE_MODEL'){return authenticatedRequest<TrustedPerson[]>(`/api/trust/people/inbound?kind=${kind}`);}
export async function addTrustedPerson(userId:number,kind:'STAR'|'ROLE_MODEL'){return authenticatedRequest<TrustedPerson>('/api/trust/people',{method:'POST',body:JSON.stringify({userId,kind})});}
export async function removeTrustedPerson(userId:number,kind:'STAR'|'ROLE_MODEL'){return authenticatedRequest<void>(`/api/trust/people/${userId}?kind=${kind}`,{method:'DELETE'});}
export async function fetchRoleModels(){return authenticatedRequest<TrustedPerson[]>('/api/trust/role-models');}
export async function followRoleModel(userId:number){return authenticatedRequest<TrustedPerson>(`/api/trust/role-models/${userId}/follow`,{method:'POST'});}
export async function fetchEmergencyRequests(){return authenticatedRequest<EmergencyRequest[]>('/api/trust/emergencies');}
export async function startEmergencyAccess(ownerUserId:number,reason:string){return authenticatedRequest<EmergencyRequest>('/api/trust/emergencies',{method:'POST',body:JSON.stringify({ownerUserId,reason})});}
export async function decideEmergencyAccess(id:number,approved:boolean){return authenticatedRequest<EmergencyRequest>(`/api/trust/emergencies/${id}/decision`,{method:'POST',body:JSON.stringify({approved})});}
export async function fetchEmergencyDocuments(id:number){return authenticatedRequest<EmergencyDocument[]>(`/api/trust/emergencies/${id}/documents`);}
export async function fetchEmergencyDocumentMedia(path:string){return authenticatedRequest<Blob>(path,{responseType:'blob'});}
export async function fetchNotifications(){return authenticatedRequest<AppNotification[]>('/api/notifications');}
export async function fetchUnreadNotificationCount(){return authenticatedRequest<{count:number}>('/api/notifications/unread-count');}
export async function markNotificationRead(id:number){return authenticatedRequest<AppNotification>(`/api/notifications/${id}/read`,{method:'POST'});}
export async function markAllNotificationsRead(){return authenticatedRequest<void>('/api/notifications/read-all',{method:'POST'});}
export async function fetchNotificationPreferences(){return authenticatedRequest<NotificationPreferences>('/api/notifications/preferences');}
export async function updateNotificationPreferences(values:NotificationPreferences){return authenticatedRequest<NotificationPreferences>('/api/notifications/preferences',{method:'PUT',body:JSON.stringify(values)});}
export async function fetchBlockedUsers(){return authenticatedRequest<BlockedUser[]>('/api/privacy/blocks');}
export async function blockUser(userId:number){return authenticatedRequest<BlockedUser>('/api/privacy/blocks',{method:'POST',body:JSON.stringify({userId})});}
export async function unblockUser(userId:number){return authenticatedRequest<void>(`/api/privacy/blocks/${userId}`,{method:'DELETE'});}
function uploadSocial<T>(path:string,body:FormData){if(path.endsWith("/stories"))body.set("retentionDays","1");return new Promise<T>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}${path}`);xhr.withCredentials=true;xhr.setRequestHeader('X-MyAaptha-Web','1');xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){try{resolve(JSON.parse(xhr.responseText) as T);}catch{reject(new ApiError(xhr.status,'The server returned an invalid response.'));}}else reject(new ApiError(xhr.status,xhr.responseText||`Upload failed (${xhr.status})`));};void validateUploadForm(body).then(()=>{xhr.timeout=90000;xhr.ontimeout=()=>reject(new ApiError(0,'Upload timed out. Please retry.'));xhr.send(body);}).catch(reject);});}
export async function fetchSocialFeed(){return authenticatedRequest<SocialPost[]>('/api/social/feed');}
export async function fetchSavedSocialPosts(){return authenticatedRequest<SocialPost[]>('/api/social/saved');}
export async function createSocialPost(caption:string,audience:SocialPost['audience'],file?:File,circleId?:number){const body=new FormData();if(caption.trim())body.append('caption',caption.trim());body.append('audience',audience);if(circleId)body.append('circleId',String(circleId));if(file)body.append('file',file);try{return await uploadSocial<SocialPost>('/api/social/posts',body);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadSocial<SocialPost>('/api/social/posts',body);}}
export async function updateSocialPost(id:number,caption:string){return authenticatedRequest<SocialPost>(`/api/social/posts/${id}`,{method:'PUT',body:JSON.stringify({caption})});}
export async function deleteSocialPost(id:number){return authenticatedRequest<void>(`/api/social/posts/${id}`,{method:'DELETE'});}
export async function toggleSocialLike(id:number){return authenticatedRequest<SocialPost>(`/api/social/posts/${id}/like`,{method:'POST'});}
export async function toggleSocialSave(id:number){return authenticatedRequest<SocialPost>(`/api/social/posts/${id}/save`,{method:'POST'});}
export async function shareSocialPost(id:number,destinationType:'DIRECT'|'CIRCLE',targetId:number,message:string){return authenticatedRequest<{destinationType:string;targetId:number;messageId:number}>(`/api/social/posts/${id}/share`,{method:'POST',body:JSON.stringify({destinationType,targetId,message})});}
export async function reportContent(payload:{reportedUserId?:number;entityType?:string;entityId?:number;reason:string;details?:string}){return authenticatedRequest<{id:number;status:string}>('/api/moderation/reports',{method:'POST',body:JSON.stringify(payload)});}
export type AbuseReport={id:number;reportedUserId?:number|null;entityType?:string|null;entityId?:number|null;reason:string;details?:string|null;status:'OPEN'|'REVIEWING'|'RESOLVED'|'DISMISSED';moderatorNotes?:string|null;createdAt:string;updatedAt:string};
export type ModerationPage={items:AbuseReport[];nextCursor:number|null};
export const fetchModerationPage=(status='OPEN',beforeId?:number)=>authenticatedRequest<ModerationPage>(`/api/moderation/reports/queue?status=${encodeURIComponent(status)}${beforeId===undefined?'':`&beforeId=${beforeId}`}`);
export async function fetchModerationReports(){return authenticatedRequest<AbuseReport[]>('/api/moderation/reports');}
export async function fetchMyReports(){return authenticatedRequest<AbuseReport[]>('/api/moderation/reports/mine');}
export async function updateModerationReport(id:number,status:AbuseReport['status'],notes:string){return authenticatedRequest<AbuseReport>(`/api/moderation/reports/${id}`,{method:'PUT',body:JSON.stringify({status,notes})});}
export async function addSocialComment(id:number,message:string){return authenticatedRequest<SocialComment>(`/api/social/posts/${id}/comments`,{method:'POST',body:JSON.stringify({message})});}
export async function deleteSocialComment(postId:number,commentId:number){return authenticatedRequest<void>(`/api/social/posts/${postId}/comments/${commentId}`,{method:'DELETE'});}
export async function fetchSocialStories(){return authenticatedRequest<SocialStory[]>('/api/social/stories');}
export async function viewSocialStory(id:number){return authenticatedRequest<SocialStory>(`/api/social/stories/${id}/view`,{method:'POST'});}
export async function createSocialStory(caption:string,audience:SocialStory['audience'],file:File){const body=new FormData();body.append('caption',caption.trim());body.append('audience',audience);body.append('file',file);try{return await uploadSocial<SocialStory>('/api/social/stories',body);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadSocial<SocialStory>('/api/social/stories',body);}}
export async function deleteSocialStory(id:number){return authenticatedRequest<void>(`/api/social/stories/${id}`,{method:'DELETE'});}
export async function fetchSocialMedia(path:string){return authenticatedRequest<Blob>(path,{responseType:'blob'});}

export async function analyzeImportedContacts(contacts:ImportedContact[]){
  return authenticatedRequest<ContactSuggestion[]>('/api/contact-organizer/analyze',{method:'POST',body:JSON.stringify({consent:true,contacts})});
}
export async function acceptImportedContacts(suggestions:ContactSuggestion[]){
  return authenticatedRequest<ContactOrganizerResult>('/api/contact-organizer/accept',{method:'POST',body:JSON.stringify({consent:true,suggestions:suggestions.map(item=>({displayName:item.display_name,phone:item.phone,email:item.email,relationship:item.suggested_relationship,circles:item.suggested_circles,selected:item.selected===true}))})});
}
export async function startContactOAuth(email:string,provider:'google'|'microsoft'){
  return authenticatedRequest<{authorizationUrl:string;provider:string;resultKey:string}>('/api/contact-organizer/oauth/start',{method:'POST',body:JSON.stringify({email,provider})});
}
export async function fetchContactOAuthResult(resultKey:string){
  const result=await authenticatedRequest<unknown>(`/api/contact-organizer/oauth/results/${encodeURIComponent(resultKey)}`);
  if(result && typeof result==='object' && 'status' in result && result.status==='failed') {
    throw new ApiError(422,'message' in result && typeof result.message==='string'?result.message:'Contact authorization failed. Nothing was saved.');
  }
  if(!Array.isArray(result)) throw new ApiError(502,'The contact provider returned an invalid result. Please try again.');
  return result as ContactSuggestion[];
}

export async function searchNetworkPeople(query: string) {
  return authenticatedRequest<NetworkPerson[]>(`/api/network/search?q=${encodeURIComponent(query)}`);
}
export async function rankNetworkPeople(query:string,candidates:NetworkPerson[]){
  if(!query.trim()||candidates.length<2)return candidates;
  try{
    const ranked=await authenticatedRequest<{id:number|string;score:number}[]>('/api/ai/search/rank',{method:'POST',body:JSON.stringify({query:query.trim(),candidates:candidates.map(person=>({id:person.id,name:person.displayName,location:person.location||''}))})});
    const scores=new Map(ranked.map(item=>[Number(item.id),item.score]));
    return [...candidates].sort((a,b)=>(scores.get(b.id)||0)-(scores.get(a.id)||0));
  }catch{return candidates;}
}

export async function fetchMyRelationships() {
  return authenticatedRequest<NetworkRelationship[]>('/api/network/relationships');
}

export async function previewRelationshipBroadcast(audienceType:BroadcastAudienceType,anchorUserId?:number,location?:string,levels?:number){
  const params=new URLSearchParams({audienceType});
  if(levels!==undefined)params.set('levels',String(levels));
  if(anchorUserId)params.set('anchorUserId',String(anchorUserId));
  if(location?.trim())params.set('location',location.trim());
  return authenticatedRequest<BroadcastAudience>(`/api/network/broadcasts/preview?${params}`);
}
function uploadRelationshipBroadcast(body:FormData,onProgress?:(percentage:number)=>void){return new Promise<BroadcastResult>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/broadcasts`);xhr.withCredentials=true;xhr.setRequestHeader('X-MyAaptha-Web','1');xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Broadcast could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as BroadcastResult);}catch{reject(new ApiError(xhr.status,'The server returned an invalid broadcast response.'));}return;}let message=`Broadcast failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};message=parsed.message||parsed.error||message;}catch{if(xhr.responseText)message=xhr.responseText;}reject(new ApiError(xhr.status,message));};void validateUploadForm(body).then(()=>{xhr.timeout=90000;xhr.ontimeout=()=>reject(new ApiError(0,'Upload timed out. Please retry.'));xhr.send(body);}).catch(reject);});}
export async function sendRelationshipBroadcast(audienceType:BroadcastAudienceType,message:string,anchorUserId?:number,location?:string,file?:File,onProgress?:(percentage:number)=>void,levels?:number){const body=new FormData();if(levels!==undefined)body.append('levels',String(levels));body.append('audienceType',audienceType);body.append('message',message.trim());if(anchorUserId)body.append('anchorUserId',String(anchorUserId));if(location?.trim())body.append('location',location.trim());if(file)body.append('file',file);try{return await uploadRelationshipBroadcast(body,onProgress);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadRelationshipBroadcast(body,onProgress);}}

export async function fetchRelationshipTypes() {
  return authenticatedRequest<string[]>('/api/network/relationship-types');
}

export async function addMyRelationship(relatedUserId: number, type: string, visibilityScope: VisibilityScope, visibilityCompany?: string, dates?: {milestoneDate?:string;dateOfBirth?:string;dateOfDeath?:string}) {
  return authenticatedRequest<NetworkRelationship>('/api/network/relationships', {
    method: 'POST', body: JSON.stringify({ relatedUserId, type, visibilityScope, visibilityCompany, ...dates }),
  });
}

export async function addPersonToMyNetwork(payload: { fullName: string; phoneNumber?: string; email?: string; type: string; visibilityScope: VisibilityScope; visibilityCompany?: string; identityType?: 'ACCOUNT' | 'MANAGED'; managedCategory?: 'CHILD' | 'MEMORIAL' | 'OTHER'; dateOfBirth?: string; dateOfDeath?: string; milestoneDate?: string; notes?: string; relativeToUserId?: number }) {
  return authenticatedRequest<NetworkRelationship>('/api/network/relationships/add-person', {
    method: 'POST', body: JSON.stringify(payload),
  });
}

export async function removeMyRelationship(id: number) {
  return authenticatedRequest<void>(`/api/network/relationships/${id}`, { method: 'DELETE' });
}

export type RelationshipImportRowResult = { rowNumber: number; fullName: string; success: boolean; message: string; createdUserId: number | null; relationshipId: number | null };
export type RelationshipImportResult = { totalRows: number; successCount: number; errorCount: number; rows: RelationshipImportRowResult[] };
export async function bulkImportRelationships(file: File) {
  const body = new FormData(); body.append('file', file);
  return authenticatedRequest<RelationshipImportResult>('/api/network/relationships/bulk-import', { method: 'POST', body });
}
export async function downloadRelationshipImportTemplate() {
  const blob = await authenticatedRequest<Blob>('/api/network/relationships/bulk-import/template', { responseType: 'blob' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url; link.download = 'relationship_bulk_import_template.xlsx';
  document.body.appendChild(link); link.click(); link.remove();
  URL.revokeObjectURL(url);
}

export async function updateMyRelationship(id: number, payload: { contactName: string; contactPhone?: string; contactEmail?: string; type: string; visibilityScope: VisibilityScope; visibilityCompany?: string; milestoneDate?:string; dateOfBirth?:string; dateOfDeath?:string }) {
  return authenticatedRequest<NetworkRelationship>(`/api/network/relationships/${id}`, {
    method: 'PUT', body: JSON.stringify(payload),
  });
}

export async function fetchMyCircles() {
  return authenticatedRequest<NetworkCircle[]>('/api/network/circles');
}

export async function createMyCircle(name: string, description: string) {
  return authenticatedRequest<NetworkCircle>('/api/network/circles', {
    method: 'POST', body: JSON.stringify({ name, description }),
  });
}

export async function updateMyCircle(circleId: number, name: string, description: string, postingPermission: CirclePostingPermission) {
  return authenticatedRequest<NetworkCircle>(`/api/network/circles/${circleId}`, {
    method: 'PUT', body: JSON.stringify({ name, description, postingPermission }),
  });
}

export async function fetchCirclePosts(circleId:number,beforeId?:number){return authenticatedRequest<CirclePost[]>(`/api/network/circles/${circleId}/posts?limit=50${beforeId===undefined?'':`&beforeId=${beforeId}`}`);}
export async function fetchCircleUnreadCounts(){return authenticatedRequest<Record<string,number>>('/api/network/circles/unread-counts');}
export async function heartbeatPresence(){return authenticatedRequest<void>('/api/network/presence/heartbeat',{method:'POST'});}
export async function fetchDirectPresence(userId:number){return authenticatedRequest<PresenceStatus>(`/api/network/presence/direct/${userId}`);}
export async function setDirectTyping(userId:number,typing:boolean){return authenticatedRequest<void>(`/api/network/presence/direct/${userId}/typing`,{method:'POST',body:JSON.stringify({typing})});}
export async function fetchCirclePresence(circleId:number){return authenticatedRequest<PresenceStatus>(`/api/network/presence/circles/${circleId}`);}
export async function setCircleTyping(circleId:number,typing:boolean){return authenticatedRequest<void>(`/api/network/presence/circles/${circleId}/typing`,{method:'POST',body:JSON.stringify({typing})});}
function uploadCirclePostRequest(circleId:number,body:FormData,onProgress?:(percentage:number)=>void){return new Promise<CirclePost>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/circles/${circleId}/posts`);xhr.withCredentials=true;xhr.setRequestHeader('X-MyAaptha-Web','1');xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as CirclePost);}catch{reject(new ApiError(xhr.status,'The server returned an invalid upload response.'));}return;}let message=`Upload failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};message=parsed.message||parsed.error||message;}catch{if(xhr.responseText)message=xhr.responseText;}reject(new ApiError(xhr.status,message));};void validateUploadForm(body).then(()=>{xhr.timeout=90000;xhr.ontimeout=()=>reject(new ApiError(0,'Upload timed out. Please retry.'));xhr.send(body);}).catch(reject);});}
export async function createCirclePost(circleId:number,message:string,file?:File,parentPostId?:number,onProgress?:(percentage:number)=>void){const body=new FormData();if(message.trim())body.append('message',message.trim());if(file)body.append('file',file);if(parentPostId)body.append('parentPostId',String(parentPostId));try{return await uploadCirclePostRequest(circleId,body,onProgress);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadCirclePostRequest(circleId,body,onProgress);}}
export async function editCirclePost(circleId:number,postId:number,message:string){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}`,{method:'PUT',body:JSON.stringify({message})});}
export async function deleteCirclePost(circleId:number,postId:number){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}`,{method:'DELETE'});}
export async function searchCirclePosts(circleId:number,query:string){return authenticatedRequest<CirclePost[]>(`/api/network/circles/${circleId}/posts/search?q=${encodeURIComponent(query)}`);}
export async function reactCirclePost(circleId:number,postId:number,emoji:string){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}/reaction`,{method:'POST',body:JSON.stringify({emoji})});}
export async function fetchCircleAttachment(circleId:number,postId:number){return authenticatedRequest<Blob>(`/api/network/circles/${circleId}/posts/${postId}/attachment`,{responseType:'blob'});}
export async function fetchDirectMessages(otherUserId:number,beforeId?:number){return authenticatedRequest<DirectMessage[]>(`/api/network/messages/with/${otherUserId}?limit=50${beforeId===undefined?'':`&beforeId=${beforeId}`}`);}
export async function fetchDirectConversations(){return authenticatedRequest<DirectConversation[]>('/api/network/messages/conversations');}
function uploadDirectMessageRequest(otherUserId:number,body:FormData,onProgress?:(percentage:number)=>void){return new Promise<DirectMessage>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/messages/with/${otherUserId}`);xhr.withCredentials=true;xhr.setRequestHeader('X-MyAaptha-Web','1');xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as DirectMessage);}catch{reject(new ApiError(xhr.status,'The server returned an invalid upload response.'));}return;}let errorMessage=`Message failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};errorMessage=parsed.message||parsed.error||errorMessage;}catch{if(xhr.responseText)errorMessage=xhr.responseText;}reject(new ApiError(xhr.status,errorMessage));};void validateUploadForm(body).then(()=>{xhr.timeout=90000;xhr.ontimeout=()=>reject(new ApiError(0,'Upload timed out. Please retry.'));xhr.send(body);}).catch(reject);});}
export async function sendDirectMessage(otherUserId:number,message:string,file?:File,onProgress?:(percentage:number)=>void,replyToMessageId?:number){const body=new FormData();if(message.trim())body.append('message',message.trim());if(file)body.append('file',file);if(replyToMessageId)body.append('replyToMessageId',String(replyToMessageId));try{return await uploadDirectMessageRequest(otherUserId,body,onProgress);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadDirectMessageRequest(otherUserId,body,onProgress);}}
export async function searchDirectMessages(otherUserId:number,query:string){return authenticatedRequest<DirectMessage[]>(`/api/network/messages/with/${otherUserId}/search?q=${encodeURIComponent(query)}`);}
export async function editDirectMessage(otherUserId:number,messageId:number,message:string){return authenticatedRequest<DirectMessage>(`/api/network/messages/with/${otherUserId}/${messageId}`,{method:'PUT',body:JSON.stringify({message})});}
export async function deleteDirectMessage(otherUserId:number,messageId:number){return authenticatedRequest<DirectMessage>(`/api/network/messages/with/${otherUserId}/${messageId}`,{method:'DELETE'});}
export async function reactDirectMessage(otherUserId:number,messageId:number,emoji:string){return authenticatedRequest<DirectMessage>(`/api/network/messages/with/${otherUserId}/${messageId}/reaction`,{method:'POST',body:JSON.stringify({emoji})});}
export async function fetchDirectMessageAttachment(otherUserId:number,messageId:number){return authenticatedRequest<Blob>(`/api/network/messages/with/${otherUserId}/${messageId}/attachment`,{responseType:'blob'});}
export async function startDirectCall(recipientId:number,callType:'AUDIO'|'VIDEO',offerSdp:string){return authenticatedRequest<DirectCall>('/api/network/calls',{method:'POST',body:JSON.stringify({recipientId,callType,offerSdp})});}
export async function fetchIncomingCalls(){return authenticatedRequest<DirectCall[]>('/api/network/calls/incoming');}
export async function fetchDirectCall(callId:number){return authenticatedRequest<DirectCall>(`/api/network/calls/${callId}`);}
export async function acceptDirectCall(callId:number,answerSdp:string){return authenticatedRequest<DirectCall>(`/api/network/calls/${callId}/accept`,{method:'POST',body:JSON.stringify({answerSdp})});}
export async function rejectDirectCall(callId:number){return authenticatedRequest<DirectCall>(`/api/network/calls/${callId}/reject`,{method:'POST'});}
export async function endDirectCall(callId:number){return authenticatedRequest<DirectCall>(`/api/network/calls/${callId}/end`,{method:'POST'});}

export async function addMemberToMyCircle(circleId: number, userId: number) {
  return authenticatedRequest<NetworkCircle>(`/api/network/circles/${circleId}/members`, {
    method: 'POST', body: JSON.stringify({ userId }),
  });
}

export async function removeMemberFromMyCircle(circleId: number, userId: number) {
  return authenticatedRequest<NetworkCircle>(`/api/network/circles/${circleId}/members/${userId}`, { method: 'DELETE' });
}

export async function promoteCircleAdmin(circleId: number, userId: number) {
  return authenticatedRequest<NetworkCircle>(`/api/network/circles/${circleId}/admins/${userId}`, { method: 'POST' });
}

export async function demoteCircleAdmin(circleId: number, userId: number) {
  return authenticatedRequest<NetworkCircle>(`/api/network/circles/${circleId}/admins/${userId}`, { method: 'DELETE' });
}

export async function fetchPeople() {
  return authenticatedRequest<any[]>('/api/people');
}

export async function createPerson(payload: { fullName: string; email: string; gender?: string }) {
  return authenticatedRequest<any>('/api/people', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updatePerson(id: number, payload: { fullName: string; email: string; gender?: string }) {
  return authenticatedRequest<any>(`/api/people/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchCircles() {
  return authenticatedRequest<any[]>('/api/circles');
}

export async function createCircle(payload: { name: string; description: string }) {
  return authenticatedRequest<any>('/api/circles', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateCircle(id: number, payload: { name: string; description: string }) {
  return authenticatedRequest<any>(`/api/circles/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchRelationships() {
  return authenticatedRequest<any[]>('/api/relationships');
}

export async function createRelationship(payload: { type: string }) {
  return authenticatedRequest<any>('/api/relationships', { method: 'POST', body: JSON.stringify(payload) });
}

export async function createTaskGroup(payload: { name: string; description: string }) {
  return authenticatedRequest<any>('/api/task-groups', { method: 'POST', body: JSON.stringify(payload) });
}

export async function fetchTaskGroups() {
  return authenticatedRequest<any[]>('/api/task-groups');
}

export async function updateRelationship(id: number, payload: { type: string }) {
  return authenticatedRequest<any>(`/api/relationships/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchPermissions() {
  return authenticatedRequest<any[]>('/api/permissions');
}

export async function updatePermission(id: number, payload: { name: string; description: string }) {
  return authenticatedRequest<any>(`/api/permissions/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchProjects() {
  return authenticatedRequest<any[]>('/api/projects');
}

export async function createProject(payload: { name: string; description: string; status: string }) {
  return authenticatedRequest<any>('/api/projects', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateProject(id: number, payload: { name: string; description: string; status: string }) {
  return authenticatedRequest<any>(`/api/projects/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchTasks() {
  return authenticatedRequest<any[]>('/api/tasks');
}

export async function fetchTasksByMilestone(milestoneId: number) {
  return authenticatedRequest<any[]>(`/api/tasks?milestoneId=${milestoneId}`);
}

export async function createTask(payload: { title: string; details: string; status: string; projectId?: number; milestoneId?: number }) {
  return authenticatedRequest<any>('/api/tasks', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateTask(id: number, payload: { title: string; details: string; status: string; projectId?: number; milestoneId?: number }) {
  return authenticatedRequest<any>(`/api/tasks/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function fetchMilestones() {
  return authenticatedRequest<any[]>('/api/milestones');
}

export async function createMilestone(payload: { name: string; description: string; status: string; projectId?: number; dueDate?: string; blockedReason?: string }) {
  return authenticatedRequest<any>('/api/milestones', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updateMilestone(id: number, payload: { name: string; description: string; status: string; projectId?: number; dueDate?: string; blockedReason?: string }) {
  return authenticatedRequest<any>(`/api/milestones/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

export async function bulkUpdateMilestoneStatus(milestoneIds: number[], status: string, blockedReason?: string) {
  return authenticatedRequest<any[]>('/api/milestones/bulk-status', {
    method: 'POST',
    body: JSON.stringify({ milestoneIds, status, blockedReason }),
  });
}

export async function deleteMilestone(id: number) {
  return authenticatedRequest<void>(`/api/milestones/${id}`, {
    method: 'DELETE',
  });
}

export async function fetchDashboardSummary() {
  return authenticatedRequest<any>('/api/dashboard/summary');
}

export type FinancialTransaction={id:number;amount:number;direction:'EXPENSE'|'INCOME';category:string;merchant?:string;description?:string;occurredAt:string;source:'MANUAL'|'SMS'|'IMPORT'};
export type FinancialSummary={income:number;spending:number;net:number;categories:Record<string,number>;transactions:FinancialTransaction[];suggestions:string[];disclaimer:string};
export type RenewalInput={kind:'BILL'|'WARRANTY'|'SERVICE';title:string;provider:string;referenceNumber:string;amount:number|null;purchasedOn:string|null;expiresOn:string;timezone:string;notes:string;remindersEnabled:boolean;archived:boolean};
export type RenewalItem=RenewalInput & {id:number;daysRemaining:number;status:string;nextReminderAt:string|null;reminderDays:number[];attachmentUrl:string|null;attachmentName:string|null;attachmentType:string|null};
export const fetchRenewals=()=>authenticatedRequest<RenewalItem[]>('/api/finance/renewals');
export const saveRenewal=(value:RenewalInput,id?:number)=>{
  const {kind,title,provider,referenceNumber,amount,purchasedOn,expiresOn,timezone,notes,remindersEnabled,archived}=value;
  return authenticatedRequest<RenewalItem>(`/api/finance/renewals${id?`/${id}`:''}`,{method:id?'PUT':'POST',body:JSON.stringify({kind,title,provider,referenceNumber,amount,purchasedOn,expiresOn,timezone,notes,remindersEnabled,archived})});
};
export const deleteRenewal=(id:number)=>authenticatedRequest<void>(`/api/finance/renewals/${id}`,{method:'DELETE'});
export const setRenewalState=(id:number,state:{archived?:boolean;remindersEnabled?:boolean})=>authenticatedRequest<RenewalItem>(`/api/finance/renewals/${id}/state`,{method:'PUT',body:JSON.stringify(state)});
export const attachRenewalReceipt=(id:number,file:File)=>{const body=new FormData();body.set('file',file);return authenticatedRequest<RenewalItem>(`/api/finance/renewals/${id}/attachment`,{method:'POST',body});};
export const removeRenewalReceipt=(id:number)=>authenticatedRequest<void>(`/api/finance/renewals/${id}/attachment`,{method:'DELETE'});
export const fetchRenewalReceipt=(id:number)=>authenticatedRequest<Blob>(`/api/finance/renewals/${id}/attachment`,{responseType:'blob'});
export async function fetchFinancialSummary(month:string){return authenticatedRequest<FinancialSummary>(`/api/finance/summary?month=${month}`);}
export async function addFinancialTransaction(payload:{amount?:number;direction?:string;category?:string;merchant?:string;description?:string;occurredAt?:string;source:string;smsBody?:string;smsSender?:string}){return authenticatedRequest<FinancialTransaction>('/api/finance/transactions',{method:'POST',body:JSON.stringify(payload)});}
export async function deleteFinancialTransaction(id:number){return authenticatedRequest<void>(`/api/finance/transactions/${id}`,{method:'DELETE'});}
export type HealthMeasurement={id:number;metricName:string;value:number;unit:string;referenceMin?:number|null;referenceMax?:number|null;rangeStatus:'BELOW'|'ABOVE'|'IN_RANGE';suggestion?:string|null};
export type HealthReport={id:number;sourcePostId?:number|null;sourceMediaName?:string|null;sourceMediaUrl?:string|null;reportName:string;laboratory?:string|null;collectedOn:string;notes?:string|null;measurements:HealthMeasurement[]};
export type HealthDashboard={reports:HealthReport[];trends:{metricName:string;unit:string;points:{date:string;value:number;referenceMin?:number|null;referenceMax?:number|null;reportId:number}[]}[];disclaimer:string};
export async function fetchHealthDashboard(){return authenticatedRequest<HealthDashboard>('/api/health/dashboard');}
export async function addHealthReport(payload:{sourcePostId?:number;reportName:string;laboratory?:string;collectedOn:string;notes?:string;measurements:{metricName:string;value:number;unit:string;referenceMin?:number;referenceMax?:number}[]}){return authenticatedRequest<HealthReport>('/api/health/reports',{method:'POST',body:JSON.stringify(payload)});}
export async function analyzeHealthReport(file:File,processingConsent:boolean){if(!processingConsent)throw new Error('Consent to external processing is required for this report.');if(file.size>25*1024*1024)throw new Error('Report must be 25 MB or smaller.');if(!['application/pdf','image/jpeg','image/png'].includes(file.type))throw new Error('Choose a PDF, JPEG or PNG report.');const body=new FormData();body.append('file',file);body.append('processingConsent','true');return authenticatedRequest<HealthReport>('/api/health/reports/analyze',{method:'POST',body});}
export async function deleteHealthReport(id:number){return authenticatedRequest<void>(`/api/health/reports/${id}`,{method:'DELETE'});}
export type AiActionEvent={requestId:string;capability:string;actionLevel:'L0'|'L1'|'L2'|'L3'|'L4';purpose:string;consentGranted:boolean;approvalState:string;status:'STARTED'|'SUCCEEDED'|'FAILED'|'REJECTED';failureCode?:string|null;createdAt:string;completedAt?:string|null};
export async function fetchAiActivity(){return authenticatedRequest<AiActionEvent[]>('/api/ai/activity');}
export type AiPreference={userId:number;aiEnabled:boolean;allowSensitiveData:boolean;allowPersonalization:boolean;activityRetentionDays:number;updatedAt?:string|null};
export async function fetchAiPreferences(){return authenticatedRequest<AiPreference>('/api/ai/preferences');}
export async function updateAiPreferences(payload:Omit<AiPreference,'userId'|'updatedAt'>){return authenticatedRequest<AiPreference>('/api/ai/preferences',{method:'PUT',body:JSON.stringify(payload)});}
export type AiActionApproval={id:string;capability:string;actionLevel:'L2'|'L3';title:string;summary:string;resourceType?:string|null;resourceId?:string|null;status:'PENDING'|'APPROVED'|'REJECTED'|'EXPIRED'|'CANCELLED';decisionReason?:string|null;requestedAt:string;expiresAt:string;decidedAt?:string|null;authorizationExpiresAt?:string|null};
export async function fetchAiApprovals(){return authenticatedRequest<AiActionApproval[]>('/api/ai/approvals');}
export async function decideAiApproval(id:string,decision:'APPROVED'|'REJECTED',reason?:string){return authenticatedRequest<AiActionApproval>(`/api/ai/approvals/${encodeURIComponent(id)}/decision`,{method:'PUT',body:JSON.stringify({decision,reason:reason?.trim()||null})});}
export type AiActionExecution={id:string;approvalId:string;status:'RUNNING'|'SUCCEEDED'|'FAILED';failureCode?:string|null;resultReference?:string|null;startedAt:string;completedAt?:string|null};
export async function fetchAiExecutions(){return authenticatedRequest<AiActionExecution[]>('/api/ai/executions');}

export async function securityPolicy(){return request<{phoneVerificationRequired:boolean}>('/api/auth/security-policy',{skipAuth:true});}
export async function requestPhoneCode(phoneNumber:string,captchaToken:string){return request<void>('/api/auth/phone/start',{method:'POST',body:JSON.stringify({phoneNumber,captchaToken}),skipAuth:true});}
export async function resetPassword(phoneNumber:string,verificationCode:string,password:string){return request<void>('/api/auth/reset-password',{method:'POST',body:JSON.stringify({phoneNumber,verificationCode,password}),skipAuth:true});}

export type ApplicationSettings = {
  discoverable:boolean; shareConnections:boolean; shareInterests:boolean; intelligentSearch:boolean;
  compactLayout:boolean; reducedMotion:boolean; quietHoursEnabled:boolean;
  quietStart:string; quietEnd:string; timeZone:string; notificationPreviews:boolean;
};
export type DiscoveryMatch = {
  person:NetworkPerson; alreadyConnected:boolean; relationship:string|null;
  mutualConnections:Array<{userId:number;displayName:string;yourRelationship:string;sharedRelationship:string}>;
  sharedInterests:string[]; sharedEmployer:string|null; reasons:string[]; relevance:number;
};
export type DiscoveryResult = {people:DiscoveryMatch[];rankingMode:string;limited:boolean;explanation:string};
export async function discoverPeople(query:string) { return authenticatedRequest<DiscoveryResult>(`/api/network/discover?q=${encodeURIComponent(query)}`); }
export async function fetchApplicationSettings() { return authenticatedRequest<ApplicationSettings>('/api/settings/me'); }
export async function updateApplicationSettings(values:ApplicationSettings) {
  const saved=await authenticatedRequest<ApplicationSettings>('/api/settings/me',{method:'PUT',body:JSON.stringify(values)});
  if(typeof window!=='undefined')window.dispatchEvent(new CustomEvent('myaaptha:settings-updated',{detail:saved}));
  return saved;
}

export async function setMessageFlags(other:number,id:number,flags:{starred?:boolean;pinned?:boolean}) {return authenticatedRequest<DirectMessage>(`/api/network/messages/with/${other}/${id}/flags`,{method:'PUT',body:JSON.stringify(flags)});}
export async function fetchSavedMessages(other:number,kind:'starred'|'pinned',beforeId?:number) {return authenticatedRequest<DirectMessage[]>(`/api/network/messages/with/${other}/saved?kind=${kind}&limit=50${beforeId===undefined?'':`&beforeId=${beforeId}`}`);}
export async function acknowledgeMessages(other:number,messageIds:number[]) {return authenticatedRequest<void>(`/api/network/messages/with/${other}/read`,{method:'POST',body:JSON.stringify({messageIds})});}
export async function pinConversation(other:number,pinned:boolean) {return authenticatedRequest<void>(`/api/network/messages/with/${other}/pin`,{method:'PUT',body:JSON.stringify({pinned})});}
export async function messagePreferences() {return authenticatedRequest<{readReceipts:boolean}>('/api/network/messages/preferences');}
export async function saveMessagePreferences(readReceipts:boolean) {return authenticatedRequest<{readReceipts:boolean}>('/api/network/messages/preferences',{method:'PUT',body:JSON.stringify({readReceipts})});}

export type AddressCircle={id:number;name:string;privateContactCount:number};
export const fetchAddressCircles=()=>authenticatedRequest<AddressCircle[]>('/api/address-book/circles');
export const assignAddressCircles=(id:number,circleIds:number[])=>authenticatedRequest<void>(`/api/address-book/${id}/circles`,{method:'PUT',body:JSON.stringify({circleIds})});

export async function saveChatSettings(other:number,settings:{archived?:boolean;muted?:boolean;markedUnread?:boolean}) {return authenticatedRequest<void>(`/api/network/messages/with/${other}/settings`,{method:"PUT",body:JSON.stringify(settings)});}

export async function forwardDirectMessage(other:number,id:number,recipientId:number) {return authenticatedRequest<DirectMessage>(`/api/network/messages/with/${other}/${id}/forward`,{method:"POST",body:JSON.stringify({recipientId})});}

export async function deleteDirectMessageForMe(other:number,id:number){return authenticatedRequest<void>(`/api/network/messages/with/${other}/${id}/for-me`,{method:"DELETE"});}
export async function deleteCirclePostForMe(circle:number,id:number){return authenticatedRequest<void>(`/api/network/circles/${circle}/posts/${id}/for-me`,{method:"DELETE"});}

export type ChatTarget={type:'DIRECT'|'CIRCLE';id:number;name:string};
export type CircleConversation={circleId:number;displayName:string;lastMessage:string;lastMessageAt:string|null;unreadCount:number};
export const fetchCircleConversations=()=>authenticatedRequest<CircleConversation[]>('/api/network/chats/circles');
export const forwardChatMessage=(sourceType:'DIRECT'|'CIRCLE',conversationId:number,messageId:number,targets:Pick<ChatTarget,'type'|'id'>[])=>authenticatedRequest<{sent:number}>('/api/network/chats/forward',{method:'POST',body:JSON.stringify({sourceType,conversationId,messageId,targets})});
export const setCircleMessageFlags=(circle:number,id:number,flags:{starred?:boolean;pinned?:boolean})=>authenticatedRequest<CirclePost>(`/api/network/chats/circles/${circle}/${id}/flags`,{method:'PUT',body:JSON.stringify(flags)});
export async function fetchForwardTargets():Promise<ChatTarget[]>{
  const [relationships,chats,circles]=await Promise.all([fetchMyRelationships(),fetchDirectConversations(),fetchMyCircles()]);
  const people=new Map<number,string>();chats.forEach(chat=>people.set(chat.userId,chat.displayName));
  relationships.filter(r=>r.person.accountStatus==='ACTIVE'&&r.person.identityType!=='MANAGED').forEach(r=>people.set(r.person.id,r.person.displayName));
  return [...Array.from(people,([id,name])=>({type:'DIRECT' as const,id,name})),...circles.filter(c=>c.currentUserCanPost).map(c=>({type:'CIRCLE' as const,id:c.id,name:c.name}))];
}

export async function fetchFollowConnections(kind:'following'|'followers',page=0){return authenticatedRequest<{people:TrustedPerson[];hasNext:boolean}>(`/api/trust/${kind}?page=${page}`);}
export async function unfollowRoleModel(id:number){return authenticatedRequest<void>(`/api/trust/role-models/${id}/follow`,{method:'DELETE'});}

export const healthAiStatus=()=>authenticatedRequest<{configured:boolean;consentRequired:boolean;provider:string}>('/api/health/ai-status');

export function setHelpEnhanced(enhancedEnabled:boolean) {return authenticatedRequest('/api/ai/help/admin/settings',{method:'PUT',body:JSON.stringify({enhancedEnabled})});}
export function clearHelpHistory(){return authenticatedRequest('/api/ai/help/history',{method:'DELETE'});}
export function clearSharedHelp(){return authenticatedRequest('/api/ai/help/admin/answers',{method:'DELETE'});}
export function publishHelpAnswer(question:string,answer:string,sourceIds:string[]){return authenticatedRequest('/api/ai/help/admin/answers',{method:'POST',body:JSON.stringify({question,answer,sourceIds,confirmedPublic:true})});}

export type SecurityIncident={id:number;occurredAt:string;category:string;summary:string;requestPath:string;ipAddress:string;actor:string|null;blockedUntil:string|null;resolvedAt:string|null;emailStatus:string};
export const fetchSecurityReports=(page=0)=>authenticatedRequest<{items:SecurityIncident[];antivirusReady:boolean;emailConfigured:boolean;blockMinutes:number}>(`/api/admin/security?page=${page}`);
export const updateSecurityReport=(id:number,action:'resolve'|'unblock')=>authenticatedRequest<void>(`/api/admin/security/${id}/${action}`,{method:'POST'});

export type UploadLevel={id:number;name:string;storageBytes:number;uploadBytes:number;maxRetentionDays:number;allowNever:boolean};
export type UploadUsage={level:UploadLevel;usedBytes:number};
export const fetchUploadPolicy=()=>authenticatedRequest<UploadUsage>('/api/uploads/policy');
export const fetchUploadLevels=()=>authenticatedRequest<UploadLevel[]>('/api/admin/upload-levels');
export const saveUploadLevel=(level:UploadLevel)=>authenticatedRequest<UploadLevel>('/api/admin/upload-levels',{method:'PUT',body:JSON.stringify(level)});
export const assignUploadLevel=(userId:number,levelId:number)=>authenticatedRequest<void>(`/api/admin/upload-levels/users/${userId}`,{method:'PUT',body:JSON.stringify({levelId})});
async function validateUploadForm(body:FormData){
 await validateUploadFiles(body);
 const files=Array.from(body.values()).filter((v):v is File=>typeof v!=='string'&&v.size>0);
 if(!files.length)return;
 const policy=await fetchUploadPolicy();
 if(files.some(f=>f.size>policy.level.uploadBytes))throw new Error(`Your ${policy.level.name} level allows ${(policy.level.uploadBytes/1048576).toFixed(1)} MB per file.`);
 if(files.reduce((n,f)=>n+f.size,policy.usedBytes)>policy.level.storageBytes)throw new Error('Storage is full. Remove files or ask your administrator about another level.');
 if(!body.has('retentionDays'))body.set('retentionDays',String(await chooseUploadRetention(policy.level)));
}

export type ChatSearchHit={type:'DIRECT'|'CIRCLE';conversationId:number;messageId:number;name:string;text:string;createdAt:string};
export const searchAllChats=(q:string)=>authenticatedRequest<ChatSearchHit[]>(`/api/network/chats/search?q=${encodeURIComponent(q)}`);
export const createChatGroup=(name:string,memberIds:number[])=>authenticatedRequest<NetworkCircle>('/api/network/chats/groups',{method:'POST',body:JSON.stringify({name,memberIds})});

export type SavedTimelineEvent={eventKey:string;date:string;kind:string;title:string;detail:string};
export const fetchTimelineEvents=()=>authenticatedRequest<SavedTimelineEvent[]>('/api/timeline/events');
export const deleteTimelineEvent=(key:string)=>authenticatedRequest<void>(`/api/timeline/events/${encodeURIComponent(key)}`,{method:'DELETE'});
export const saveTimelineEvent=(event:SavedTimelineEvent)=>authenticatedRequest<SavedTimelineEvent>(`/api/timeline/events/${encodeURIComponent(event.eventKey)}`,{method:'PUT',body:JSON.stringify(event)});

export async function reactSocialPost(id:number,emoji:string|null){return authenticatedRequest<SocialPost>(`/api/social/posts/${id}/reaction`,{method:'PUT',body:JSON.stringify({emoji})});}
export async function pinSocialPost(id:number,pinned:boolean){return authenticatedRequest<SocialPost>(`/api/social/posts/${id}/pin`,{method:'PUT',body:JSON.stringify({pinned})});}

export type CallIceConfiguration={iceServers:RTCIceServer[];relayConfigured:boolean;credentialsExpireAt:number|null};
export const fetchCallIceConfiguration=()=>authenticatedRequest<CallIceConfiguration>('/api/network/calls/ice');
