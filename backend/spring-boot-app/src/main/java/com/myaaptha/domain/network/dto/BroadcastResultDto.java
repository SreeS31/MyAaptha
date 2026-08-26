package com.myaaptha.domain.network.dto;

import java.time.Instant;
import java.util.List;

public record BroadcastResultDto(Long broadcastId, String audienceType, int deliveredCount,
    int failedCount, List<String> failures, Instant createdAt) {}
