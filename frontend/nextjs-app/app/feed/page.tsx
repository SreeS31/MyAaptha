'use client';

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
  toggleSocialLike,
  toggleSocialSave,
  shareSocialPost,
  reportContent,
  updateSocialPost,
  viewSocialStory,
} from '../lib/api';

function Media({ path, type, alt, onViewed }: { path: string; type?: string | null; alt: string; onViewed?:()=>void }) {
  const [url, setUrl] = useState('');
  const [fullScreen, setFullScreen] = useState(false);
  const [scale, setScale] = useState(1);
  const onViewedRef = useRef(onViewed);
  useEffect(() => { onViewedRef.current = onViewed; }, [onViewed]);
  useEffect(() => {
    let object = '';
    fetchSocialMedia(path).then(blob => { object = URL.createObjectURL(blob); setUrl(object); onViewedRef.current?.(); }).catch(() => setUrl(''));
    return () => { if (object) URL.revokeObjectURL(object); };
  }, [path]);
  if (!url) return <div className="social-media-loading">Loading media…</div>;
  if (type?.startsWith('video/')) return <video className="social-media" src={url} controls playsInline />;
  if (type?.startsWith('image/')) return <><button type="button" className="social-media-thumbnail" onClick={()=>{setScale(1);setFullScreen(true);}} aria-label={`Open ${alt} full screen`}><img src={url} alt={alt}/><span>⌕ View full size</span></button>{fullScreen&&<div className="social-image-viewer" role="dialog" aria-modal="true" aria-label={`${alt} image viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setFullScreen(false);}} onWheel={event=>{event.preventDefault();setScale(value=>Math.max(.5,Math.min(8,value*(event.deltaY<0?1.15:.87))));}}><header><strong>{alt}</strong><button type="button" onClick={()=>setFullScreen(false)} aria-label="Close image viewer">×</button></header><div className="social-image-stage"><img src={url} alt={alt} style={{transform:`scale(${scale})`}}/></div><nav aria-label="Image zoom controls"><button type="button" onClick={()=>setScale(value=>Math.max(.5,value/1.35))} aria-label="Zoom out">−</button><button type="button" onClick={()=>setScale(1)}>Reset</button><output>{Math.round(scale*100)}%</output><button type="button" onClick={()=>setScale(value=>Math.min(8,value*1.35))} aria-label="Zoom in">＋</button></nav></div>}</>;
  return <a className="social-document btn btn-secondary" href={url} download><span aria-hidden="true">▤</span><span>View or download document</span></a>;
}

function AttachmentMedia({path,type,name,alt}:{path:string;type?:string|null;name?:string|null;alt:string}){
  const [url,setUrl]=useState('');
  const [viewer,setViewer]=useState(false);
  const [menu,setMenu]=useState<{x?:number;y?:number}|null>(null);
  useEffect(()=>{let object='';fetchSocialMedia(path).then(blob=>{object=URL.createObjectURL(blob);setUrl(object);}).catch(()=>setUrl(''));return()=>{if(object)URL.revokeObjectURL(object);};},[path]);
  useEffect(()=>{if(!menu)return;const close=()=>setMenu(null);window.addEventListener('click',close);window.addEventListener('scroll',close,true);return()=>{window.removeEventListener('click',close);window.removeEventListener('scroll',close,true);};},[menu]);
  if(!url)return <div className="social-media-loading">Loading media...</div>;
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
  if(isVideo)return <div className="social-media-shell" onContextMenu={context}><video className="social-media" src={url} controls playsInline preload="metadata"/>{more}{actions}</div>;
  if(isAudio)return <div className="social-media-shell social-audio-shell" onContextMenu={context}><div className="social-audio-label"><span aria-hidden="true">♪</span><strong>{filename}</strong></div><audio className="social-audio" src={url} controls preload="metadata"/>{more}{actions}</div>;
  if(isImage)return <div className="social-media-shell" onContextMenu={context}><button type="button" className="social-media-thumbnail" onClick={open} aria-label={`Open ${alt} full screen`}><img src={url} alt={alt}/><span>View full size</span></button>{more}{actions}{viewer&&<div className="social-document-viewer social-photo-viewer" role="dialog" aria-modal="true" aria-label={`${alt} image viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setViewer(false);}}><header><strong>{filename}</strong><div><button type="button" onClick={download} title="Download">↓</button><button type="button" onClick={()=>window.open(url,'_blank','noopener,noreferrer')} title="Open in new tab">↗</button><button type="button" onClick={()=>setViewer(false)} aria-label="Close viewer">×</button></div></header><div><img src={url} alt={alt}/></div></div>}</div>;
  return <div className="social-document-shell" onContextMenu={context}><button type="button" className="social-document" onClick={open}><span aria-hidden="true">▤</span><span><strong>{filename}</strong><small>Click to preview</small></span></button>{more}{actions}{viewer&&<div className="social-document-viewer" role="dialog" aria-modal="true" aria-label={`${filename} document viewer`} onMouseDown={event=>{if(event.target===event.currentTarget)setViewer(false);}}><header><strong>{filename}</strong><div><button type="button" onClick={download} title="Download">↓</button><button type="button" onClick={()=>window.open(url,'_blank','noopener,noreferrer')} title="Open in new tab">↗</button><button type="button" onClick={()=>setViewer(false)} aria-label="Close document viewer">×</button></div></header><iframe src={url} title={filename}/></div>}</div>;
}

function Avatar({ name, src, userId }: { name: string; src?: string | null; userId?: number }) {
  const avatar = src ? <img className="social-avatar" src={src} alt="" /> : <span className="social-avatar social-avatar-text">{name.charAt(0).toUpperCase()}</span>;
  return userId ? <Link className="person-avatar-link" href={`/people/${userId}`} title={`View ${name}'s profile`}>{avatar}</Link> : avatar;
}

function FeedContent() {
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
  const [comments, setComments] = useState<Record<number, string>>({});
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [savedOnly, setSavedOnly] = useState(false);
  const [diaryOnly, setDiaryOnly] = useState(false);
  const [sharePost,setSharePost]=useState<SocialPost|null>(null);
  const [shareType,setShareType]=useState<'DIRECT'|'CIRCLE'>('DIRECT');
  const [shareTarget,setShareTarget]=useState('');
  const [shareNote,setShareNote]=useState('');

  const load = useCallback(async () => {
    try {
      const [postData, storyData, circleData, relationshipData] = await Promise.all([savedOnly ? fetchSavedSocialPosts() : fetchSocialFeed(), fetchSocialStories(), fetchMyCircles(), fetchMyRelationships()]);
      setPosts(postData); setStories(storyData); setCircles(circleData); setRelationships(relationshipData);
    } catch (error) {
      if (isUnauthorizedError(error)) router.replace('/auth?reason=session-expired');
      else setMessage((error as Error).message);
    }
  }, [router, savedOnly]);

  useEffect(() => { if (!hasAuthSession()) router.replace('/auth'); else void load(); }, [load, router]);
  useEffect(() => {
    const postId = Number(searchParams.get('postId'));
    const index = posts.findIndex(post => post.id === postId);
    if (index < 0) return;
    window.setTimeout(() => document.querySelectorAll<HTMLElement>('.social-post')[index]?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 0);
  }, [posts, searchParams]);

  const publish = async (event: FormEvent) => {
    event.preventDefault(); setBusy(true); setMessage('');
    try { await createSocialPost(caption, audience, file, audience === 'CIRCLE' ? Number(circleId) : undefined); setCaption(''); setFile(undefined); await load(); }
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

  return <main className="social-page">
    <header className="social-header"><div><small>MY DIGITAL DIARY</small><h1>{diaryOnly?'Your memories':savedOnly?'Saved moments':'Thoughts, memories and moments'}</h1><p>Keep important information, feelings, photos, videos and documents—with you in control of every entry.</p></div><nav><button className={`btn ${diaryOnly?'btn-primary':'btn-secondary'}`} onClick={()=>{setDiaryOnly(value=>!value);setSavedOnly(false);}}>{diaryOnly?'All entries':'My diary'}</button><button className="btn btn-secondary" onClick={()=>{setSavedOnly(value=>!value);setDiaryOnly(false);}}>{savedOnly?'All posts':'Saved posts'}</button><Link href="/dashboard" className="btn btn-secondary">Relationships</Link><Link href="/profile" className="btn btn-secondary">Profile</Link></nav></header>
    {message && <p className="network-message error-message" role="alert">{message}</p>}
    <section className="story-strip">
      <label className="story-create"><strong>＋ Story</strong><input hidden type="file" accept="image/*,video/*" onChange={event => setStoryFile(event.target.files?.[0])} /><input value={storyCaption} onChange={event => setStoryCaption(event.target.value)} placeholder="Caption" />{storyFile && <button disabled={busy} onClick={publishStory}>Share</button>}</label>
      {stories.map(story => <article className={`story-card ${story.viewedByMe?'story-watched':''}`} key={story.id}><Media path={story.mediaUrl} type={story.mediaType} alt={story.caption || `${story.authorName}'s story`} onViewed={story.mine?undefined:()=>{if(!story.viewedByMe)void viewSocialStory(story.id).then(updated=>setStories(current=>current.map(item=>item.id===updated.id?updated:item)));}}/><div><Avatar name={story.authorName} src={story.authorPhoto} userId={story.authorUserId}/><strong>{story.authorName}</strong>{story.mine&&<small>{story.viewCount} view{story.viewCount===1?'':'s'}</small>}{story.mine && <button aria-label="Delete story" onClick={async () => { await deleteSocialStory(story.id); await load(); }}>×</button>}</div>{story.caption && <p>{story.caption}</p>}</article>)}
    </section>
    <form className="social-composer diary-composer card" onSubmit={publish}><div><span className="diary-composer-icon" aria-hidden="true">✎</span><div><h2>Write in your diary</h2><p>Capture a thought, feeling, memory or important information.</p></div></div><textarea value={caption} maxLength={4000} onChange={event => setCaption(event.target.value)} placeholder="What would you like to remember today?" /><div className="social-compose-actions"><label className="audience-field"><span>Who can view this?</span><select value={audience} onChange={event => {setAudience(event.target.value as SocialPost['audience']);setCircleId('');}}><option value="PRIVATE">Private — only me</option><option value="PUBLIC">Public — everyone</option><option value="FRIENDS">Friends</option><option value="RELATIVES">Relatives</option><option value="RELATIONSHIPS">All my relationships</option><option value="CIRCLE">Selected circle</option></select></label>{audience === 'CIRCLE' && <label className="audience-field"><span>Select a circle</span><select required value={circleId} onChange={event => setCircleId(event.target.value)}><option value="">Choose circle…</option>{circles.map(circle => <option key={circle.id} value={circle.id}>{circle.name}</option>)}</select></label>}<label className="btn btn-secondary diary-file-button">{file ? file.name : 'Attach document, photo or video'}<input hidden type="file" accept="image/*,video/*,audio/*,.pdf,.txt,.doc,.docx,.xls,.xlsx,.ppt,.pptx" onChange={event => setFile(event.target.files?.[0])} /></label>{file&&<button type="button" className="diary-remove-file" onClick={()=>setFile(undefined)} aria-label="Remove attachment">×</button>}<button className="btn btn-primary" disabled={busy || (!caption.trim() && !file) || (audience==='CIRCLE'&&!circleId)}>{busy ? 'Saving…' : audience==='PRIVATE'?'Save privately':'Share entry'}</button></div></form>
    <section className="social-feed">
      {posts.filter(post=>!diaryOnly||post.mine).length === 0 && <div className="card social-empty"><h2>{diaryOnly?'Your diary is ready':'No entries yet'}</h2><p>{diaryOnly?'Write your first private thought or save an important memory above.':'Create an entry or connect with people to see their shared moments.'}</p></div>}
      {posts.filter(post=>!diaryOnly||post.mine).map(post => <article className={`social-post card ${post.audience==='PRIVATE'?'diary-private-entry':''} ${Number(searchParams.get('postId')) === post.id ? 'is-targeted' : ''}`} key={post.id}>
        <header><Avatar name={post.authorName} src={post.authorPhoto} userId={post.authorUserId}/><div><strong>{post.authorName}</strong><small>{new Date(post.createdAt).toLocaleString()} · {post.audience==='PRIVATE'?'Private · only you':post.audience==='CIRCLE'?'Selected circle':post.audience==='RELATIONSHIPS'?'All relationships':post.audience.charAt(0)+post.audience.slice(1).toLowerCase()}{post.updatedAt !== post.createdAt ? ' · edited' : ''}</small></div>{post.mine && <div className="social-owner-actions"><button onClick={() => void editPost(post)}>Edit</button><button className="social-delete" onClick={async () => { if (confirm('Delete this entry?')) { await deleteSocialPost(post.id); await load(); } }}>Delete</button></div>}</header>
        {post.caption && <p className="social-caption">{post.caption}</p>}{post.mediaUrl && <div className="social-attachment"><AttachmentMedia path={post.mediaUrl} type={post.mediaType} name={post.mediaName} alt={post.caption || post.mediaName || 'Diary attachment'} /></div>}
        <div className="social-stats"><span>{post.likeCount} like{post.likeCount === 1 ? '' : 's'}</span><span>{post.commentCount} comment{post.commentCount === 1 ? '' : 's'}</span></div>
        <div className="social-actions"><button className={post.likedByMe ? 'is-liked' : ''} onClick={async () => { await toggleSocialLike(post.id); await load(); }}>{post.likedByMe ? '♥ Liked' : '♡ Like'}</button><button className={post.savedByMe?'is-saved':''} onClick={async()=>{await toggleSocialSave(post.id);await load();}}>{post.savedByMe?'🔖 Saved':'♧ Save'}</button><button onClick={()=>{setSharePost(post);setShareTarget('');setShareNote('');}}>↗ Share</button>{!post.mine&&<button onClick={()=>void reportPost(post)}>⚑ Report</button>}</div>
        <div className="social-comments">{post.comments.map(comment => <div key={comment.id}><Avatar name={comment.authorName} src={comment.authorPhoto} userId={comment.authorUserId}/><p><strong>{comment.authorName}</strong> {comment.message}</p>{(comment.mine || post.mine) && <button aria-label="Delete comment" onClick={async () => { await deleteSocialComment(post.id, comment.id); await load(); }}>×</button>}</div>)}<form onSubmit={async event => { event.preventDefault(); const text = comments[post.id]?.trim(); if (!text) return; await addSocialComment(post.id, text); setComments(current => ({ ...current, [post.id]: '' })); await load(); }}><input value={comments[post.id] || ''} onChange={event => setComments(current => ({ ...current, [post.id]: event.target.value }))} placeholder="Write a comment…" /><button>Post</button></form></div>
      </article>)}
    </section>
    {sharePost&&<div className="direct-chat-backdrop" role="presentation" onMouseDown={event=>{if(event.target===event.currentTarget)setSharePost(null);}}><section className="card social-share-dialog" role="dialog" aria-modal="true"><header><div><small>SHARE POST</small><h2>Send privately</h2></div><button className="btn btn-secondary" onClick={()=>setSharePost(null)}>Close</button></header><label><span>Destination</span><select value={shareType} onChange={event=>{setShareType(event.target.value as 'DIRECT'|'CIRCLE');setShareTarget('');}}><option value="DIRECT">Direct conversation</option><option value="CIRCLE">Circle</option></select></label><label><span>{shareType==='DIRECT'?'Person':'Circle'}</span><select required value={shareTarget} onChange={event=>setShareTarget(event.target.value)}><option value="">Choose…</option>{shareType==='DIRECT'?relationships.filter((item,index,all)=>item.person.accountStatus==='ACTIVE'&&item.person.identityType!=='MANAGED'&&all.findIndex(candidate=>candidate.person.id===item.person.id)===index).map(item=><option key={item.person.id} value={item.person.id}>{item.person.displayName}</option>):circles.map(circle=><option key={circle.id} value={circle.id}>{circle.name}</option>)}</select></label><label><span>Message (optional)</span><textarea value={shareNote} onChange={event=>setShareNote(event.target.value)} maxLength={1000}/></label><button className="btn btn-primary" disabled={!shareTarget||busy} onClick={async()=>{setBusy(true);try{await shareSocialPost(sharePost.id,shareType,Number(shareTarget),shareNote);setMessage('Post shared successfully.');setSharePost(null);}catch(error){setMessage((error as Error).message);}finally{setBusy(false);}}}>Share post</button></section></div>}
  </main>;
}

export default function FeedPage() {
  return <Suspense fallback={<main className="social-page"><div className="card social-empty"><p>Loading your feed…</p></div></main>}><FeedContent /></Suspense>;
}
