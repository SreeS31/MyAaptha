package com.myaaptha.domain.social;
import java.time.Instant; import java.util.List;
public final class SocialDtos { private SocialDtos(){}
 public record Comment(Long id,Long authorUserId,String authorName,String authorPhoto,String message,Instant createdAt,boolean mine){}
 public record Post(Long id,Long authorUserId,String authorName,String authorPhoto,String caption,String audience,Long circleId,String mediaUrl,String mediaName,String mediaType,Long mediaSize,long likeCount,long commentCount,boolean likedByMe,boolean savedByMe,boolean mine,Instant createdAt,Instant updatedAt,List<Comment> comments,java.util.Map<String,Long> reactions,String myReaction,boolean pinned,boolean repostedByMe,long repostCount,Long repostedByUserId,String repostedByName,Instant feedAt){
 public Post withRepost(Long by,String name,Instant at){return new Post(id,authorUserId,authorName,authorPhoto,caption,audience,circleId,mediaUrl,mediaName,mediaType,mediaSize,likeCount,commentCount,likedByMe,savedByMe,mine,createdAt,updatedAt,comments,reactions,myReaction,pinned,repostedByMe,repostCount,by,name,at);}
 }
 public record Story(Long id,Long authorUserId,String authorName,String authorPhoto,String caption,String audience,String mediaUrl,String mediaType,Instant createdAt,Instant expiresAt,long viewCount,boolean viewedByMe,boolean mine,String highlightName){}
 public record RepostRequest(boolean reposted){}
 public record ReactionRequest(String emoji){} public record PinRequest(Boolean pinned){}
 public record CaptionRequest(String caption){} public record CommentRequest(String message){}
 public record ShareRequest(String destinationType,Long targetId,String message){}
 public record ShareResult(String destinationType,Long targetId,Long messageId){}
}
