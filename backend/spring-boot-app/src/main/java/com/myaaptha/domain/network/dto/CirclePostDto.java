package com.myaaptha.domain.network.dto;

import java.time.Instant;
import java.util.Map;

public record CirclePostDto(Long id,Long circleId,Long parentPostId,Long authorId,String authorName,String authorPhoto,
    String message,String attachmentUrl,String attachmentName,String attachmentType,Long attachmentSize,Instant createdAt,
    Instant editedAt,Instant deletedAt,Map<String,Long> reactions,String myReaction,long readCount,boolean currentUserAuthor) {}
