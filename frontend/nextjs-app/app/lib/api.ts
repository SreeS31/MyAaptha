const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ||
  (process.env.NODE_ENV === 'production' ? '' : 'http://localhost:8080');
const AUTH_SESSION_KEY = 'myaaptha.auth.session';

export type AuthSession = {
  tokenType: string;
  accessToken: string;
  refreshToken: string;
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
    const session=getStoredAuthSession();const request=new XMLHttpRequest();request.open('POST',`${API_BASE_URL}/api/people/${id}/memories`);if(session?.accessToken)request.setRequestHeader('Authorization',`${session.tokenType||'Bearer'} ${session.accessToken}`);
    const announce=(progress:number,status:'uploading'|'processing'|'complete'|'error',message:string)=>window.dispatchEvent(new CustomEvent('myaaptha:upload-progress',{detail:{progress,status,message,fileName:file?.name||'Memory'}}));
    announce(0,'uploading','Preparing upload…');request.upload.onprogress=event=>{if(event.lengthComputable)announce(Math.min(99,Math.round(event.loaded/event.total*100)),'uploading','Uploading memory…');};request.upload.onload=()=>announce(99,'processing','Upload received. Saving memory…');
    request.onerror=()=>{announce(0,'error','Upload failed');reject(new ApiError(0,'The upload connection failed. If this is a cloud file, download it locally and try again.'));};
    request.onload=async()=>{if(request.status>=200&&request.status<300){announce(100,'complete','Upload completed');try{resolve(JSON.parse(request.responseText) as PersonMemory);window.setTimeout(()=>{const gallery=document.querySelector<HTMLDetailsElement>('.memory-gallery-disclosure');if(gallery){gallery.open=true;gallery.scrollIntoView({behavior:'smooth',block:'start'});}},700);}catch{reject(new ApiError(request.status,'The upload completed but its response could not be read.'));}return;}if(request.status===401&&mayRefresh){announce(0,'processing','Refreshing session…');try{await refreshSessionOrThrow();resolve(await upload(false));}catch{clearAuthSession();announce(0,'error','Session expired');reject(new ApiError(401,'Session expired. Please sign in again.'));}return;}let message=`Request failed: ${request.status}`;try{const value=JSON.parse(request.responseText) as {message?:string;error?:string};message=value.message||value.error||message;}catch{}announce(0,'error',message);reject(new ApiError(request.status,message));};request.send(body);
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

function getStoredAuthSession(): StoredAuthSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  const raw = window.localStorage.getItem(AUTH_SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as Partial<StoredAuthSession>;
    if (!parsed.accessToken || !parsed.refreshToken || !parsed.tokenType || !parsed.expiresIn) {
      window.localStorage.removeItem(AUTH_SESSION_KEY);
      return null;
    }

    if (typeof parsed.receivedAtEpochMs === 'number' && typeof parsed.expiresAtEpochMs === 'number') {
      return parsed as StoredAuthSession;
    }

    const migratedSession: StoredAuthSession = {
      tokenType: parsed.tokenType,
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken,
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
    ...session,
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
  return !!session?.accessToken && !!session.refreshToken;
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
  const session = getStoredAuthSession();
  const headers: Record<string, string> = {
    ...(init?.body instanceof FormData ? {} : { 'Content-Type': 'application/json' }),
    ...(init?.headers as Record<string, string> || {}),
  };

  if (!init?.skipAuth && session?.accessToken) {
    headers.Authorization = `${session.tokenType || 'Bearer'} ${session.accessToken}`;
  }

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, { ...init, headers });
  } catch (error) {
    if (init?.body instanceof FormData) throw new ApiError(0, 'The browser could not read or upload this file. If it is stored in OneDrive or another cloud folder, download it to this device or start the cloud provider, then choose it again.');
    throw error;
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

async function refreshSessionOrThrow() {
  const currentSession = getStoredAuthSession();
  if (!currentSession?.refreshToken) {
    throw new ApiError(401, 'Missing refresh token');
  }

  const refreshedSession = await request<AuthSession>('/api/auth/refresh', {
    method: 'POST',
    body: JSON.stringify({ refreshToken: currentSession.refreshToken }),
    skipAuth: true,
  });
  setStoredAuthSession(refreshedSession);
  return refreshedSession;
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

export async function login(identifier: string, password: string) {
  const session = await request<AuthSession>('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ identifier, password }),
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

export async function logout() {
  const session = getStoredAuthSession();
  if (!session?.refreshToken) {
    clearAuthSession();
    return;
  }

  try {
    await request<void>('/api/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refreshToken: session.refreshToken }),
      skipAuth: true,
    });
  } finally {
    clearAuthSession();
  }
}

export async function revokeSession() {
  const session = getStoredAuthSession();
  if (!session?.refreshToken) {
    clearAuthSession();
    return;
  }

  try {
    await request<void>('/api/auth/revoke', {
      method: 'POST',
      body: JSON.stringify({ refreshToken: session.refreshToken }),
      skipAuth: true,
    });
  } finally {
    clearAuthSession();
  }
}

export async function fetchUsers() {
  return authenticatedRequest<any[]>('/api/users');
}

export async function createUser(payload: { username: string; email?: string; phoneNumber: string; password: string; firstName?: string; surname?: string; location?: string }) {
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
export type NetworkCircle = { id: number; name: string; description: string; members: NetworkCircleMember[]; ownerName: string; ownerPhoto?: string | null; ownedByCurrentUser: boolean; currentUserAdmin: boolean; postingPermission: CirclePostingPermission; currentUserCanPost: boolean };
export type CirclePost = { id:number; circleId:number; parentPostId?:number|null; authorId:number; authorName:string; authorPhoto?:string|null; message:string; attachmentUrl?:string|null; attachmentName?:string|null; attachmentType?:string|null; attachmentSize?:number|null; createdAt:string; editedAt?:string|null; deletedAt?:string|null; reactions:Record<string,number>; myReaction?:string|null; readCount:number; currentUserAuthor:boolean };
export type DirectMessage = { id:number; senderId:number; recipientId:number; senderName:string; senderPhoto?:string|null; message:string; attachmentUrl?:string|null; attachmentName?:string|null; attachmentType?:string|null; attachmentSize?:number|null; createdAt:string; deliveredAt?:string|null; readAt?:string|null; replyToMessageId?:number|null; replyPreview?:string|null; editedAt?:string|null; deletedAt?:string|null; reactions:Record<string,number>; myReaction?:string|null; currentUserAuthor:boolean };
export type DirectConversation = { userId:number; displayName:string; profilePhoto?:string|null; lastMessage:string; lastMessageAt:string; unreadCount:number };
export type DirectCall = { id:number; callerId:number; recipientId:number; callerName:string; callerPhoto?:string|null; recipientName:string; recipientPhoto?:string|null; callType:'AUDIO'|'VIDEO'; status:'RINGING'|'ACCEPTED'|'REJECTED'|'ENDED'; offerSdp:string; answerSdp?:string|null; createdAt:string; updatedAt:string; currentUserCaller:boolean };
export type BroadcastAudienceType = 'HORIZONTAL' | 'VERTICAL' | 'LOCATION';
export type BroadcastRecipient = { userId:number; displayName:string; relationship:string; location?:string|null; profilePhoto?:string|null };
export type BroadcastAudience = { audienceType:BroadcastAudienceType; anchorUserId?:number|null; locationQuery?:string|null; recipients:BroadcastRecipient[]; excludedCount:number };
export type BroadcastResult = { broadcastId:number; audienceType:BroadcastAudienceType; deliveredCount:number; failedCount:number; failures:string[]; createdAt:string };
export type ImportedContact = { contact_key:string; display_name:string; phones:string[]; emails:string[]; organization:string; job_title:string; labels:string[] };
export type ContactSuggestion = { contact_key:string; display_name:string; phone?:string|null; email?:string|null; suggested_relationship:string; suggested_circles:string[]; confidence:number; reasons:string[]; requires_review:boolean; selected?:boolean };
export type ContactOrganizerResult = { peopleAdded:number; circleMembershipsAdded:number; skipped:string[] };
export type SocialComment = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; message:string; createdAt:string; mine:boolean };
export type SocialPost = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; caption:string; audience:'PRIVATE'|'PUBLIC'|'FRIENDS'|'RELATIVES'|'RELATIONSHIPS'|'CIRCLE'; circleId?:number|null; mediaUrl?:string|null; mediaName?:string|null; mediaType?:string|null; mediaSize?:number|null; likeCount:number; commentCount:number; likedByMe:boolean; savedByMe:boolean; mine:boolean; createdAt:string; updatedAt:string; comments:SocialComment[] };
export type SocialStory = { id:number; authorUserId:number; authorName:string; authorPhoto?:string|null; caption:string; audience:'PUBLIC'|'RELATIONSHIPS'; mediaUrl:string; mediaType:string; createdAt:string; expiresAt:string; viewCount:number; viewedByMe:boolean; mine:boolean };
export type BlockedUser = { userId:number; displayName:string; profilePhoto?:string|null; blockedAt:string };
export type AppNotification = { id:number; type:string; title:string; body:string; actionUrl?:string|null; entityType?:string|null; entityId?:number|null; readAt?:string|null; createdAt:string };
export type PresenceStatus = { online:boolean; lastActiveAt?:string|null; typingUsers:{userId:number;displayName:string}[] };
export type NotificationPreferences = { emailEnabled:boolean; smsEnabled:boolean; pushEnabled:boolean; messagesEnabled:boolean; circlesEnabled:boolean; relationshipsEnabled:boolean; callsEnabled:boolean; invitationsEnabled:boolean; socialEnabled:boolean };
export type TrustedPerson = { userId:number; displayName:string; profilePhoto?:string|null; kind:'STAR'|'ROLE_MODEL'; followerCount:number; addedAt:string };
export type EmergencyRequest = { id:number; ownerUserId:number; ownerName:string; requesterUserId:number; requesterName:string; reason:string; status:'PENDING'|'APPROVED'|'REJECTED'|'EXPIRED'; approvals:number; requiredApprovals:number; createdAt:string; expiresAt:string; grantedUntil?:string|null };
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
function uploadSocial<T>(path:string,body:FormData){return new Promise<T>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}${path}`);if(session?.accessToken)xhr.setRequestHeader('Authorization',`${session.tokenType||'Bearer'} ${session.accessToken}`);xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){try{resolve(JSON.parse(xhr.responseText) as T);}catch{reject(new ApiError(xhr.status,'The server returned an invalid response.'));}}else reject(new ApiError(xhr.status,xhr.responseText||`Upload failed (${xhr.status})`));};xhr.send(body);});}
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
  return authenticatedRequest<ContactSuggestion[]>(`/api/contact-organizer/oauth/results/${encodeURIComponent(resultKey)}`);
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

export async function previewRelationshipBroadcast(audienceType:BroadcastAudienceType,anchorUserId?:number,location?:string){
  const params=new URLSearchParams({audienceType});
  if(anchorUserId)params.set('anchorUserId',String(anchorUserId));
  if(location?.trim())params.set('location',location.trim());
  return authenticatedRequest<BroadcastAudience>(`/api/network/broadcasts/preview?${params}`);
}
function uploadRelationshipBroadcast(body:FormData,onProgress?:(percentage:number)=>void){return new Promise<BroadcastResult>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/broadcasts`);if(session?.accessToken)xhr.setRequestHeader('Authorization',`${session.tokenType||'Bearer'} ${session.accessToken}`);xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Broadcast could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as BroadcastResult);}catch{reject(new ApiError(xhr.status,'The server returned an invalid broadcast response.'));}return;}let message=`Broadcast failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};message=parsed.message||parsed.error||message;}catch{if(xhr.responseText)message=xhr.responseText;}reject(new ApiError(xhr.status,message));};xhr.send(body);});}
export async function sendRelationshipBroadcast(audienceType:BroadcastAudienceType,message:string,anchorUserId?:number,location?:string,file?:File,onProgress?:(percentage:number)=>void){const body=new FormData();body.append('audienceType',audienceType);body.append('message',message.trim());if(anchorUserId)body.append('anchorUserId',String(anchorUserId));if(location?.trim())body.append('location',location.trim());if(file)body.append('file',file);try{return await uploadRelationshipBroadcast(body,onProgress);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadRelationshipBroadcast(body,onProgress);}}

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

export async function fetchCirclePosts(circleId:number){return authenticatedRequest<CirclePost[]>(`/api/network/circles/${circleId}/posts`);}
export async function fetchCircleUnreadCounts(){return authenticatedRequest<Record<string,number>>('/api/network/circles/unread-counts');}
export async function heartbeatPresence(){return authenticatedRequest<void>('/api/network/presence/heartbeat',{method:'POST'});}
export async function fetchDirectPresence(userId:number){return authenticatedRequest<PresenceStatus>(`/api/network/presence/direct/${userId}`);}
export async function setDirectTyping(userId:number,typing:boolean){return authenticatedRequest<void>(`/api/network/presence/direct/${userId}/typing`,{method:'POST',body:JSON.stringify({typing})});}
export async function fetchCirclePresence(circleId:number){return authenticatedRequest<PresenceStatus>(`/api/network/presence/circles/${circleId}`);}
export async function setCircleTyping(circleId:number,typing:boolean){return authenticatedRequest<void>(`/api/network/presence/circles/${circleId}/typing`,{method:'POST',body:JSON.stringify({typing})});}
function uploadCirclePostRequest(circleId:number,body:FormData,onProgress?:(percentage:number)=>void){return new Promise<CirclePost>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/circles/${circleId}/posts`);if(session?.accessToken)xhr.setRequestHeader('Authorization',`${session.tokenType||'Bearer'} ${session.accessToken}`);xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as CirclePost);}catch{reject(new ApiError(xhr.status,'The server returned an invalid upload response.'));}return;}let message=`Upload failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};message=parsed.message||parsed.error||message;}catch{if(xhr.responseText)message=xhr.responseText;}reject(new ApiError(xhr.status,message));};xhr.send(body);});}
export async function createCirclePost(circleId:number,message:string,file?:File,parentPostId?:number,onProgress?:(percentage:number)=>void){const body=new FormData();if(message.trim())body.append('message',message.trim());if(file)body.append('file',file);if(parentPostId)body.append('parentPostId',String(parentPostId));try{return await uploadCirclePostRequest(circleId,body,onProgress);}catch(error){if(!isUnauthorizedError(error))throw error;await refreshSessionOrThrow();return uploadCirclePostRequest(circleId,body,onProgress);}}
export async function editCirclePost(circleId:number,postId:number,message:string){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}`,{method:'PUT',body:JSON.stringify({message})});}
export async function deleteCirclePost(circleId:number,postId:number){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}`,{method:'DELETE'});}
export async function searchCirclePosts(circleId:number,query:string){return authenticatedRequest<CirclePost[]>(`/api/network/circles/${circleId}/posts/search?q=${encodeURIComponent(query)}`);}
export async function reactCirclePost(circleId:number,postId:number,emoji:string){return authenticatedRequest<CirclePost>(`/api/network/circles/${circleId}/posts/${postId}/reaction`,{method:'POST',body:JSON.stringify({emoji})});}
export async function fetchCircleAttachment(circleId:number,postId:number){return authenticatedRequest<Blob>(`/api/network/circles/${circleId}/posts/${postId}/attachment`,{responseType:'blob'});}
export async function fetchDirectMessages(otherUserId:number){return authenticatedRequest<DirectMessage[]>(`/api/network/messages/with/${otherUserId}`);}
export async function fetchDirectConversations(){return authenticatedRequest<DirectConversation[]>('/api/network/messages/conversations');}
function uploadDirectMessageRequest(otherUserId:number,body:FormData,onProgress?:(percentage:number)=>void){return new Promise<DirectMessage>((resolve,reject)=>{const session=getStoredAuthSession();const xhr=new XMLHttpRequest();xhr.open('POST',`${API_BASE_URL}/api/network/messages/with/${otherUserId}`);if(session?.accessToken)xhr.setRequestHeader('Authorization',`${session.tokenType||'Bearer'} ${session.accessToken}`);xhr.upload.onprogress=event=>{if(event.lengthComputable)onProgress?.(Math.min(99,Math.round(event.loaded/event.total*100)));};xhr.onerror=()=>reject(new ApiError(0,'Upload could not reach the server. Check your connection and try again.'));xhr.onload=()=>{if(xhr.status>=200&&xhr.status<300){onProgress?.(100);try{resolve(JSON.parse(xhr.responseText) as DirectMessage);}catch{reject(new ApiError(xhr.status,'The server returned an invalid upload response.'));}return;}let errorMessage=`Message failed (${xhr.status})`;try{const parsed=JSON.parse(xhr.responseText) as {message?:string;error?:string};errorMessage=parsed.message||parsed.error||errorMessage;}catch{if(xhr.responseText)errorMessage=xhr.responseText;}reject(new ApiError(xhr.status,errorMessage));};xhr.send(body);});}
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
export async function fetchFinancialSummary(month:string){return authenticatedRequest<FinancialSummary>(`/api/finance/summary?month=${month}`);}
export async function addFinancialTransaction(payload:{amount?:number;direction?:string;category?:string;merchant?:string;description?:string;occurredAt?:string;source:string;smsBody?:string;smsSender?:string}){return authenticatedRequest<FinancialTransaction>('/api/finance/transactions',{method:'POST',body:JSON.stringify(payload)});}
export async function deleteFinancialTransaction(id:number){return authenticatedRequest<void>(`/api/finance/transactions/${id}`,{method:'DELETE'});}
export type HealthMeasurement={id:number;metricName:string;value:number;unit:string;referenceMin?:number|null;referenceMax?:number|null;rangeStatus:'BELOW'|'ABOVE'|'IN_RANGE';suggestion?:string|null};
export type HealthReport={id:number;sourcePostId?:number|null;sourceMediaName?:string|null;sourceMediaUrl?:string|null;reportName:string;laboratory?:string|null;collectedOn:string;notes?:string|null;measurements:HealthMeasurement[]};
export type HealthDashboard={reports:HealthReport[];trends:{metricName:string;unit:string;points:{date:string;value:number;referenceMin?:number|null;referenceMax?:number|null;reportId:number}[]}[];disclaimer:string};
export async function fetchHealthDashboard(){return authenticatedRequest<HealthDashboard>('/api/health/dashboard');}
export async function addHealthReport(payload:{sourcePostId?:number;reportName:string;laboratory?:string;collectedOn:string;notes?:string;measurements:{metricName:string;value:number;unit:string;referenceMin?:number;referenceMax?:number}[]}){return authenticatedRequest<HealthReport>('/api/health/reports',{method:'POST',body:JSON.stringify(payload)});}
export async function analyzeHealthReport(file:File){if(file.size>25*1024*1024)throw new Error('Report must be 25 MB or smaller.');if(!['application/pdf','image/jpeg','image/png'].includes(file.type))throw new Error('Choose a PDF, JPEG or PNG report.');const body=new FormData();body.append('file',file);return authenticatedRequest<HealthReport>('/api/health/reports/analyze',{method:'POST',body});}
export async function deleteHealthReport(id:number){return authenticatedRequest<void>(`/api/health/reports/${id}`,{method:'DELETE'});}
