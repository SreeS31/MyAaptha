package com.myaaptha.domain.network.dto;

import java.time.Instant;
import java.util.Map;

public record DirectMessageDto(Long id,Long senderId,Long recipientId,String senderName,String senderPhoto,
    String message,String attachmentUrl,String attachmentName,String attachmentType,Long attachmentSize,
    Instant createdAt,Instant deliveredAt,Instant readAt,Long replyToMessageId,String replyPreview,
    Instant editedAt,Instant deletedAt,Map<String,Long> reactions,String myReaction,boolean currentUserAuthor) {}
