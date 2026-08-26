package com.myaaptha.domain.social;
import java.time.Instant; import java.util.List;
public final class SocialDtos { private SocialDtos(){}
 public record Comment(Long id,Long authorUserId,String authorName,String authorPhoto,String message,Instant createdAt,boolean mine){}
 public record Post(Long id,Long authorUserId,String authorName,String authorPhoto,String caption,String audience,Long circleId,String mediaUrl,String mediaName,String mediaType,Long mediaSize,long likeCount,long commentCount,boolean likedByMe,boolean savedByMe,boolean mine,Instant createdAt,Instant updatedAt,List<Comment> comments){}
 public record Story(Long id,Long authorUserId,String authorName,String authorPhoto,String caption,String audience,String mediaUrl,String mediaType,Instant createdAt,Instant expiresAt,long viewCount,boolean viewedByMe,boolean mine){}
 public record CaptionRequest(String caption){} public record CommentRequest(String message){}
 public record ShareRequest(String destinationType,Long targetId,String message){}
 public record ShareResult(String destinationType,Long targetId,Long messageId){}
}
