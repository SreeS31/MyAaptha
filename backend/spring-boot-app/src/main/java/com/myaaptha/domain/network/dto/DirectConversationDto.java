package com.myaaptha.domain.network.dto;

import java.time.Instant;

public record DirectConversationDto(Long userId, String displayName, String profilePhoto,
    String lastMessage, Instant lastMessageAt, long unreadCount) {}
