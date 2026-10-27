'use client';
import {startPolling} from '../lib/polling';
import {attachmentAccept} from '../lib/upload-security';
import InfoTip from '../components/InfoTip';
import './feed-polish.css';
import PostOptions from './PostOptions';

function FeedIcon({name}:{name:'heart'|'comment'|'save'|'share'}) {
 const paths={heart:'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z',comment:'M21 11.5a8.5 8.5 0 0 1-8.5 8.5H4l-2 2V11.5a9.5 9.5 0 0 1 19 0Z',save:'M6 3h12v19l-6-4-6 4V3Z',share:'M14 3h7v7M21 3 10 14M10 5H4v15h15v-6'};
 return <svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d={paths[name]}/></svg>;
}

import Link from 'next/link';
import { FormEvent, MouseEvent, Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  addSocialComment,
  createSocialPost,
  createSocialStory,
  deleteSocialComment,
  deleteSocialPost,
  deleteSocialStory,
  fetchMyCircles,
  fetchMyRelationships,
  fetchSocialFeed,
  fetchSavedSocialPosts,
  fetchSocialMedia,
  fetchSocialStories,
  hasAuthSession,
  isUnauthorizedError,
  NetworkCircle,
  NetworkRelationship,
  SocialPost,
  SocialStory,
  reactSocialPost,
  pinSocialPost,
  toggleSocialLike,
  toggleSocialSave,
  shareSocialPost,
  reportContent,
  updateSocialPost,
  viewSocialStory,
} from '../lib/api';

function Media({ path, type, alt, onViewed }: { path: string; type?: string | null; alt: string; onViewed?:()=>void }) {
  const [url, setUrl] = useState('');
  const [mediaFailed, setMediaFailed] = useState(false);
  const [fullScreen, setFullScreen] = useState(false);
  const [scale, setScale] = useState(1);
  const onViewedRef = useRef(onViewed);
  useEffect(() => { onViewedRef.current = onViewed; }, [onViewed]);
  useEffect(() => {
    let object = '';
    setMediaFailed(false);
    fetchSocialMedia(path).then(blob => { object = URL.createObjectURL(blob); setUrl(object); onViewedRef.current?.(); }).catch(() => { setUrl(''); setMediaFailed(true); });
    return () => { if (object) URL.revokeObjectURL(object); };
  }, [path]);
  if (!url) return <div className="social-media-loading" role="status">{mediaFailed ? 'This attachment is currently unavailable.' : 'Loading media…'}</div>;
  if (type?.startsWith('video/')) return <video className="social-media" src={url} controls playsInline />;
  if (type?.startsWith('image/')) return <><button type="button" className="social-media-thumbnail" onClick={()=>{setScale(1);setFullScreen(true);}} aria-label={`Open ${alt} full screen`}><img src={url} alt={alt}/><span>⌕ View full size</span></button>{fullScreen&&<div className="social-image-viewer" role="dialog" aria-modal="true" aria-label={`${alt} image viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setFullScreen(false);}} onWheel={event=>{event.preventDefault();setScale(value=>Math.max(.5,Math.min(8,value*(event.deltaY<0?1.15:.87))));}}><header><strong>{alt}</strong><button type="button" onClick={()=>setFullScreen(false)} aria-label="Close image viewer">×</button></header><div className="social-image-stage"><img src={url} alt={alt} style={{transform:`scale(${scale})`}}/></div><nav aria-label="Image zoom controls"><button type="button" onClick={()=>setScale(value=>Math.max(.5,value/1.35))} aria-label="Zoom out">−</button><button type="button" onClick={()=>setScale(1)}>Reset</button><output>{Math.round(scale*100)}%</output><button type="button" onClick={()=>setScale(value=>Math.min(8,value*1.35))} aria-label="Zoom in">＋</button></nav></div>}</>;
  return <a className="social-document btn btn-secondary" href={url} download><span aria-hidden="true">▤</span><span>View or download document</span></a>;
}

function PostText({text}:{text:string}) {
  const [expanded,setExpanded]=useState(false);
  const long=text.length>180||text.split('\n').length>3;
  return <div className="feed-post-text"><p className={`social-caption ${long&&!expanded?'feed-text-preview':''}`}>{text}</p>{long&&<button type="button" className="feed-read-more" aria-expanded={expanded} onClick={()=>setExpanded(value=>!value)}>{expanded?'Show less':'Read more'}</button>}</div>;
}

function AttachmentMedia({path,type,name,alt,compact=false}:{path:string;type?:string|null;name?:string|null;alt:string;compact?:boolean}){
  const [url,setUrl]=useState('');
  const [mediaFailed,setMediaFailed]=useState(false);
  const [viewer,setViewer]=useState(false);
  const [menu,setMenu]=useState<{x?:number;y?:number}|null>(null);
  const previewDialog=useRef<HTMLDialogElement>(null);
  useEffect(()=>{if(!compact)return;const dialog=previewDialog.current;if(viewer&&!dialog?.open)dialog?.showModal();else if(!viewer&&dialog?.open)dialog.close();},[viewer,compact]);
  useEffect(()=>{let object='';setMediaFailed(false);fetchSocialMedia(path).then(blob=>{object=URL.createObjectURL(blob);setUrl(object);}).catch(()=>{setUrl('');setMediaFailed(true);});return()=>{if(object)URL.revokeObjectURL(object);};},[path]);
  useEffect(()=>{if(!menu)return;const close=()=>setMenu(null);window.addEventListener('click',close);window.addEventListener('scroll',close,true);return()=>{window.removeEventListener('click',close);window.removeEventListener('scroll',close,true);};},[menu]);
  if(!url)return <div className="social-media-loading" role="status">{mediaFailed ? 'This attachment is currently unavailable.' : 'Loading media...'}</div>;
  const filename=name||'attachment';
  const extension=filename.toLowerCase().split('.').pop()||'';
  const isVideo=Boolean(type?.startsWith('video/'))||['mp4','webm','mov','m4v'].includes(extension);
  const isAudio=Boolean(type?.startsWith('audio/'))||['mp3','wav','ogg','m4a','aac','flac'].includes(extension);
  const isImage=Boolean(type?.startsWith('image/'))||['jpg','jpeg','png','gif','webp','bmp'].includes(extension);
  const download=()=>{const link=document.createElement('a');link.href=url;link.download=filename;link.click();setMenu(null);};
  const open=()=>{setViewer(true);setMenu(null);};
  const context=(event:MouseEvent)=>{event.preventDefault();setMenu({x:Math.min(event.clientX,window.innerWidth-190),y:Math.min(event.clientY,window.innerHeight-145)});};
  const actions=menu&&<div className="social-media-menu" style={menu.x===undefined?undefined:{position:'fixed',left:menu.x,top:menu.y}} onClick={event=>event.stopPropagation()} role="menu"><button role="menuitem" onClick={open}>Open</button><button role="menuitem" onClick={()=>{window.open(url,'_blank','noopener,noreferrer');setMenu(null);}}>Open in new tab</button><button role="menuitem" onClick={download}>Download</button></div>;
  const more=<button type="button" className="social-media-more" aria-label={`More options for ${filename}`} aria-haspopup="menu" aria-expanded={!!menu} onClick={event=>{event.stopPropagation();setMenu(current=>current?null:{});}}>⌄</button>;
  if(compact&&(isImage||isVideo))return <div className="feed-small-media" onContextMenu={context}><button type="button" className="feed-preview-button" aria-label={`Open ${filename} full view`} onClick={open}>{isImage?<img src={url} alt={alt}/>:<video src={url} muted playsInline preload="metadata" aria-hidden="true"/>}<span>{isVideo?'Play video':'View photo'}</span></button>{more}{actions}<dialog ref={previewDialog} className="feed-full-view" aria-label={`${filename} full view`} onCancel={()=>setViewer(false)} onClose={()=>setViewer(false)} onClick={event=>{if(event.target===event.currentTarget)setViewer(false);}}><header><strong>{filename}</strong><button type="button" onClick={download}>Download</button><button type="button" onClick={()=>window.open(url,'_blank','noopener,noreferrer')}>New tab</button><button type="button" aria-label="Close full view" onClick={()=>setViewer(false)}>Close</button></header>{viewer&&(isImage?<img src={url} alt={alt}/>:<video src={url} controls playsInline autoPlay/>)}</dialog></div>;
  if(isVideo)return <div className="social-media-shell" onContextMenu={context}><video className="social-media" src={url} controls playsInline preload="metadata"/>{more}{actions}</div>;
  if(isAudio)return <div className="social-media-shell social-audio-shell" onContextMenu={context}><div className="social-audio-label"><span aria-hidden="true">♪</span><strong>{filename}</strong></div><audio className="social-audio" src={url} controls preload="metadata"/>{more}{actions}</div>;
  if(isImage)return <div className="social-media-shell" onContextMenu={context}><button type="button" className="social-media-thumbnail" onClick={open} aria-label={`Open ${alt} full screen`}><img src={url} alt={alt}/><span>View full size</span></button>{more}{actions}{viewer&&<div className="social-document-viewer social-photo-viewer" role="dialog" aria-modal="true" aria-label={`${alt} image viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setViewer(false);}}><header><strong>{filename}</strong><div><button type="button" onClick={download} title="Download">↓</button><button type="button" onClick={()=>window.open(url,'_blank','noopener,noreferrer')} title="Open in new tab">↗</button><button type="button" onClick={()=>setViewer(false)} aria-label="Close viewer">×</button></div></header><div><img src={url} alt={alt}/></div></div>}</div>;
  return <div className="social-document-shell" onContextMenu={context}><button type="button" className="social-document" onClick={open}><span aria-hidden="true">▤</span><span><strong>{filename}</strong><small>Click to preview</small></span></button>{more}{actions}{viewer&&<div className="social-document-viewer" role="dialog" aria-modal="true" aria-label={`${filename} document viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setViewer(false);}}><header><strong>{filename}</strong><div><button type="button" onClick={download} title="Download">↓</button><button type="button" onClick={()=>window.open(url,'_blank','noopener,noreferrer')} title="Open in new tab">↗</button><button type="button" onClick={()=>setViewer(false)} aria-label="Close document viewer">×</button></div></header><iframe src={url} title={filename}/></div>}</div>;
}

function Avatar({ name, src, userId }: { name: string; src?: string | null; userId?: number }) {
  const [failed,setFailed]=useState(false);
  const avatar = src && !failed ? <img className="social-avatar" src={src} alt="" onError={()=>setFailed(true)} /> : <span className="social-avatar social-avatar-text">{name.charAt(0).toUpperCase()}</span>;
  return userId ? <Link className="person-avatar-link" href={`/people/${userId}`} title={`View ${name}'s profile`}>{avatar}</Link> : avatar;
}

function FeedContent({online=false}:{online?:boolean}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [posts, setPosts] = useState<SocialPost[]>([]);
  const [stories, setStories] = useState<SocialStory[]>([]);
  const [circles, setCircles] = useState<NetworkCircle[]>([]);
  const [relationships, setRelationships] = useState<NetworkRelationship[]>([]);
  const [caption, setCaption] = useState('');
  const [audience, setAudience] = useState<SocialPost['audience']>('PRIVATE');
  const [circleId, setCircleId] = useState('');
  const [file, setFile] = useState<File>();
  const [storyFile, setStoryFile] = useState<File>();
  const [storyCaption, setStoryCaption] = useState('');
  const [openComments, setOpenComments] = useState<Record<number, boolean>>({});
  const [pendingAction, setPendingAction] = useState<Record<number, boolean>>({});
  const [comments, setComments] = useState<Record<number, string>>({});
  const [busy, setBusy] = useState(false);
  const [notice,setNotice]=useState('');
  const [message, setMessage] = useState('');
  const [savedOnly, setSavedOnly] = useState(false);
  const [diaryOnly, setDiaryOnly] = useState(!online&&!searchParams.has('postId'));
  const [sharePost,setSharePost]=useState<SocialPost|null>(null);
  const [shareType,setShareType]=useState<'DIRECT'|'CIRCLE'>('DIRECT');
  const [shareTarget,setShareTarget]=useState('');
  const [shareNote,setShareNote]=useState('');

  const load = useCallback(async () => {
    try {
      const [postData, storyData, circleData, relationshipData] = await Promise.all([savedOnly ? fetchSavedSocialPosts() : fetchSocialFeed(), fetchSocialStories(), fetchMyCircles(), fetchMyRelationships()]);
      setPosts([...postData].sort((a,b)=>Number(!!b.pinned)-Number(!!a.pinned)||Date.parse(b.createdAt)-Date.parse(a.createdAt)||b.id-a.id)); setStories(storyData); setCircles(circleData); setRelationships(relationshipData);
    } catch (error) {
      if (isUnauthorizedError(error)) router.replace('/auth?reason=session-expired');
      else setMessage((error as Error).message);
    }
  }, [router, savedOnly]);

  useEffect(() => { if (!hasAuthSession()) router.replace('/auth'); else return startPolling(load,30000); }, [load, router]);
  useEffect(() => {
    const postId = Number(searchParams.get('postId'));
    const index = posts.findIndex(post => post.id === postId);
    if (index < 0) return;
    window.setTimeout(() => document.getElementById(`feed-post-${postId}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 0);
  }, [posts, searchParams]);

  const publish = async (event: FormEvent) => {
    event.preventDefault(); setBusy(true); setMessage('');
    try { await createSocialPost(caption, audience, file, audience === 'CIRCLE' ? Number(circleId) : undefined); setCaption(''); setFile(undefined); setAudience('PRIVATE'); setCircleId(''); await load(); }
    catch (error) { setMessage((error as Error).message); }
    finally { setBusy(false); }
  };
  const publishStory = async () => {
    if (!storyFile) return; setBusy(true);
    try { await createSocialStory(storyCaption, 'RELATIONSHIPS', storyFile); setStoryFile(undefined); setStoryCaption(''); await load(); }
    catch (error) { setMessage((error as Error).message); }
    finally { setBusy(false); }
  };
  const editPost = async (post: SocialPost) => {
    const value = window.prompt('Edit post', post.caption);
    if (value === null) return;
    try { await updateSocialPost(post.id, value); await load(); }
    catch (error) { setMessage((error as Error).message); }
  };
  const reportPost=async(post:SocialPost)=>{const reason=window.prompt('Report reason: harassment, spam, impersonation, privacy, illegal content, or other','spam');if(!reason)return;const normalized=reason.trim().toUpperCase().replaceAll(' ','_');const details=window.prompt('Additional details (optional)','')||'';try{await reportContent({reportedUserId:post.authorUserId,entityType:'SOCIAL_POST',entityId:post.id,reason:normalized,details});setMessage('Report submitted for review.');}catch(error){setMessage((error as Error).message);}};

  const act = async (id:number, action:()=>Promise<unknown>) => {
    if(pendingAction[id]) return;
    setPendingAction(current=>({...current,[id]:true}));
    try { await action(); await load(); } catch(error) { setMessage((error as Error).message); }
    finally { setPendingAction(current=>({...current,[id]:false})); }
  };

  const composer = <form id="write-memory" className="social-composer diary-composer card" onSubmit={publish}><div><span className="diary-composer-icon" aria-hidden="true">✎</span><div><div className="inline-help-heading"><h2>{online?'Share a thought':'Write in your diary'}</h2><InfoTip label="About diary entries">Capture a thought, feeling, memory or important information. Entries are private unless you choose another audience.</InfoTip></div></div></div><textarea value={caption} maxLength={4000} onChange={event => setCaption(event.target.value)} aria-label="Diary entry" placeholder="What would you like to remember today?" /><div className="diary-audience-summary" role="status"><span aria-hidden="true">◇</span>{audience==='PRIVATE'?'Only you can view this entry.':audience==='PUBLIC'?'Everyone can view this entry.':audience==='CIRCLE'?`Visible to members of ${circles.find(circle=>String(circle.id)===circleId)?.name||'the circle you select'}.`:`Visible to your ${audience==='RELATIONSHIPS'?'relationships':audience.toLowerCase()}.`}</div><div className="social-compose-actions"><label className="audience-field"><span>Who can view this?</span><select aria-label="Who can view this?" value={audience} onChange={event => {setAudience(event.target.value as SocialPost['audience']);setCircleId('');}}><option value="PRIVATE">Private — only me</option><option value="PUBLIC">Public — everyone</option><option value="FRIENDS">Friends</option><option value="RELATIVES">Relatives</option><option value="RELATIONSHIPS">All my relationships</option><option value="CIRCLE">Selected circle</option></select></label>{audience === 'CIRCLE' && <label className="audience-field"><span>Select a circle</span><select aria-label="Select a circle" required value={circleId} onChange={event => setCircleId(event.target.value)}><option value="">Choose circle…</option>{circles.map(circle => <option key={circle.id} value={circle.id}>{circle.name}</option>)}</select></label>}<label className="btn btn-secondary diary-file-button">{file ? file.name : 'Attach a memory'}<input aria-label="Attach a diary memory" className="visually-hidden-input" type="file" accept={attachmentAccept} onChange={event => setFile(event.target.files?.[0])} /></label>{file&&<button type="button" className="diary-remove-file" onClick={()=>setFile(undefined)} aria-label="Remove attachment">×</button>}<button className="btn btn-primary" disabled={busy || (!caption.trim() && !file) || (audience==='CIRCLE'&&!circleId)}>{busy ? 'Saving…' : audience==='PRIVATE'?'Save privately':'Share entry'}</button></div></form>;

  return <main className={`social-page feed-polished ${online?'online-stream':'diary-stream'}`}>
    <div className="feed-topbar"><header className="social-header"><div><small>{online?'YOUR PEOPLE, YOUR MOMENTS':'MY DIGITAL DIARY'}</small><div className="inline-help-heading"><h1>{diaryOnly?'Your memories':savedOnly?'Saved moments':online?'Online Feed':'Diary & memories'}</h1><InfoTip label="About this feature">Keep important information, feelings, photos, videos and documents—with you in control of every entry.</InfoTip></div></div><nav><button className={`btn ${diaryOnly?'btn-primary':'btn-secondary'}`} onClick={()=>{setDiaryOnly(value=>!value);setSavedOnly(false);}}>{diaryOnly?'All entries':'My diary'}</button><button className="btn btn-secondary" onClick={()=>{setSavedOnly(value=>!value);setDiaryOnly(false);}}>{savedOnly?'All posts':'Saved posts'}</button></nav></header>
    {notice&&<p className="network-message" role="status">{notice}</p>}
    {message && <p className="network-message error-message" role="alert">{message}</p>}
    {online?<details className="feed-composer-disclosure"><summary aria-label="Create a post"><span aria-hidden="true">+</span><strong>Write a post</strong></summary>{composer}</details>:composer}
    <details className="story-composer">
      <summary>Add a story <span>Photo or video</span></summary>
      <div className="story-create">
        <label>Photo or video<input type="file" accept="image/*,video/*" onChange={event => setStoryFile(event.target.files?.[0])} /></label>
        <label>Caption<input value={storyCaption} onChange={event => setStoryCaption(event.target.value)} placeholder="Add a caption" /></label>
        <button type="button" className="btn btn-primary" disabled={busy || !storyFile} onClick={publishStory}>Share story</button>
      </div>
    </details>
    </div>
    <section className="story-strip" aria-label="Stories" hidden={stories.length === 0}>
      {stories.map(story => <article className={`story-card ${story.viewedByMe?'story-watched':''}`} key={story.id}><Media path={story.mediaUrl} type={story.mediaType} alt={story.caption || `${story.authorName}'s story`} onViewed={story.mine?undefined:()=>{if(!story.viewedByMe)void viewSocialStory(story.id).then(updated=>setStories(current=>current.map(item=>item.id===updated.id?updated:item)));}}/><div><Avatar name={story.authorName} src={story.authorPhoto} userId={story.authorUserId}/><strong>{story.authorName}</strong>{story.mine&&<small>{story.viewCount} view{story.viewCount===1?'':'s'}</small>}{story.mine && <button aria-label="Delete story" onClick={async () => { await deleteSocialStory(story.id); await load(); }}>×</button>}</div>{story.caption && <p>{story.caption}</p>}</article>)}
    </section>
    <div className="feed-stream-heading"><h2>{savedOnly?'Saved moments':diaryOnly?'Your entries':'Latest moments'}</h2><span>Newest first</span></div>
    <section className="social-feed" aria-label="Posts, newest first">
      {posts.filter(post=>!diaryOnly||post.mine).length === 0 && <div className="card social-empty"><h2>{diaryOnly?'Your diary is ready':'No entries yet'}</h2><p>{diaryOnly?'Write your first private thought or save an important memory above.':'Create an entry or connect with people to see their shared moments.'}</p></div>}
      {posts.filter(post=>!diaryOnly||post.mine).map(post => <article className={`social-post card ${post.audience==='PRIVATE'?'diary-private-entry':''} ${Number(searchParams.get('postId')) === post.id ? 'is-targeted' : ''}`} key={post.id} id={`feed-post-${post.id}`} aria-label={`Post by ${post.authorName}`}>
        <header><Avatar name={post.authorName} src={post.authorPhoto} userId={post.authorUserId}/><div><strong>{post.authorName}</strong><small className="diary-entry-date">{new Date(post.createdAt).toLocaleDateString([], {day:'numeric',month:'short',year:'numeric'})}</small><small className="diary-audience-badge">{post.audience==='PRIVATE'?'Private · only you':post.audience==='CIRCLE'?'Selected circle':post.audience==='RELATIONSHIPS'?'All relationships':post.audience.charAt(0)+post.audience.slice(1).toLowerCase()}{post.updatedAt !== post.createdAt ? ' · edited' : ''}</small></div>{post.pinned&&<small className="feed-pinned-label">Pinned for you</small>}<PostOptions post={post} busy={pendingAction[post.id]} onNotice={setNotice} onReact={emoji=>act(post.id,()=>reactSocialPost(post.id,emoji))} onPin={()=>act(post.id,()=>pinSocialPost(post.id,!post.pinned))} onStar={()=>act(post.id,()=>toggleSocialSave(post.id))} onReply={()=>{setOpenComments(current=>({...current,[post.id]:true}));requestAnimationFrame(()=>document.querySelector<HTMLInputElement>(`#comments-${post.id} input`)?.focus());}} onForward={()=>{setSharePost(post);setShareTarget('');setShareNote('');}} onEdit={()=>void editPost(post)} onDelete={async()=>{if(confirm('Delete this entry?'))await act(post.id,()=>deleteSocialPost(post.id));}} onReport={()=>void reportPost(post)} onAsk={()=>{try{sessionStorage.setItem('myaaptha-help-draft',`Help me understand this post. Do not take any actions: ${post.caption||'An attachment-only post.'}`.slice(0,1200));router.push('/help');}catch{setNotice('Could not prepare the question. Open Ask MyAaptha from Account & tools.');}}}/>
        </header>
        <div className={`feed-post-content ${post.mediaUrl?'has-attachment':''}`}>{post.caption&&<PostText text={post.caption}/>} {post.mediaUrl&&<div className="social-attachment"><AttachmentMedia compact path={post.mediaUrl} type={post.mediaType} name={post.mediaName} alt={post.caption||post.mediaName||'Diary attachment'}/></div>}</div>
        <div className="social-actions feed-compact-actions">
          <button type="button" aria-label={post.likedByMe?'Unlike post':'Like post'} aria-pressed={post.likedByMe} title={post.likedByMe?'Unlike':'Like'} disabled={pendingAction[post.id]} className={post.likedByMe?'is-liked feed-reaction':'feed-reaction'} onClick={()=>void act(post.id,()=>toggleSocialLike(post.id))}><FeedIcon name="heart"/><span>{post.likeCount || 'Like'}</span></button>
          <button type="button" aria-label={`Comments (${post.commentCount})`} aria-expanded={!!openComments[post.id]} aria-controls={`comments-${post.id}`} onClick={()=>setOpenComments(current=>({...current,[post.id]:!current[post.id]}))}><FeedIcon name="comment"/><span>{post.commentCount || 'Comment'}</span></button>
          <button type="button" aria-label="Share post" title="Share post" onClick={()=>{setSharePost(post);setShareTarget('');setShareNote('');}}><FeedIcon name="share"/></button>
          <button type="button" className={`feed-save ${post.savedByMe?'is-saved':''}`} aria-label={post.savedByMe?'Unsave post':'Save post'} aria-pressed={post.savedByMe} title={post.savedByMe?'Unsave':'Save'} disabled={pendingAction[post.id]} onClick={()=>void act(post.id,()=>toggleSocialSave(post.id))}><FeedIcon name="save"/></button>
          <span className="feed-reaction-summary" aria-label="Post reactions">{Object.entries(post.reactions||{}).slice(0,2).map(([emoji,count])=><span key={emoji}>{emoji} {count}</span>)}</span>
        </div>
        <div id={`comments-${post.id}`} className="social-comments" hidden={!openComments[post.id]}>{post.comments.map(comment => <div key={comment.id}><Avatar name={comment.authorName} src={comment.authorPhoto} userId={comment.authorUserId}/><p><strong>{comment.authorName}</strong> {comment.message}</p>{(comment.mine || post.mine) && <button aria-label="Delete comment" disabled={pendingAction[post.id]} onClick={()=>void act(post.id,()=>deleteSocialComment(post.id, comment.id))}>×</button>}</div>)}<form onSubmit={async event => { event.preventDefault(); const text = comments[post.id]?.trim(); if (!text) return; await act(post.id,async()=>{await addSocialComment(post.id,text);setComments(current=>({...current,[post.id]:''}));}); }}><input aria-label="Write a comment" value={comments[post.id] || ''} maxLength={1000} onChange={event => setComments(current => ({ ...current, [post.id]: event.target.value }))} placeholder="Write a comment..." /><button disabled={pendingAction[post.id]||!comments[post.id]?.trim()}>Post</button></form></div>
      </article>)}
    </section>
    {sharePost&&<div className="direct-chat-backdrop" role="presentation" onMouseDown={event=>{if(event.target===event.currentTarget)setSharePost(null);}}><section className="card social-share-dialog" role="dialog" aria-modal="true"><header><div><small>SHARE POST</small><h2>Send privately</h2></div><button className="btn btn-secondary" onClick={()=>setSharePost(null)}>Close</button></header><label><span>Destination</span><select value={shareType} onChange={event=>{setShareType(event.target.value as 'DIRECT'|'CIRCLE');setShareTarget('');}}><option value="DIRECT">Direct conversation</option><option value="CIRCLE">Circle</option></select></label><label><span>{shareType==='DIRECT'?'Person':'Circle'}</span><select required value={shareTarget} onChange={event=>setShareTarget(event.target.value)}><option value="">Choose…</option>{shareType==='DIRECT'?relationships.filter((item,index,all)=>item.person.accountStatus==='ACTIVE'&&item.person.identityType!=='MANAGED'&&all.findIndex(candidate=>candidate.person.id===item.person.id)===index).map(item=><option key={item.person.id} value={item.person.id}>{item.person.displayName}</option>):circles.map(circle=><option key={circle.id} value={circle.id}>{circle.name}</option>)}</select></label><label><span>Message (optional)</span><textarea value={shareNote} onChange={event=>setShareNote(event.target.value)} maxLength={1000}/></label><button className="btn btn-primary" disabled={!shareTarget||busy} onClick={async()=>{setBusy(true);try{await shareSocialPost(sharePost.id,shareType,Number(shareTarget),shareNote);setMessage('Post shared successfully.');setSharePost(null);}catch(error){setMessage((error as Error).message);}finally{setBusy(false);}}}>Share post</button></section></div>}
  </main>;
}

export default function FeedWorkspace({online=false}:{online?:boolean}) {
  return <Suspense fallback={<main className="social-page"><div className="card social-empty"><p>Loading your feed…</p></div></main>}><FeedContent online={online} /></Suspense>;
}
