package com.myaaptha.domain.network.dto;

import java.util.List;

public record BroadcastAudienceDto(String audienceType, Long anchorUserId, String locationQuery,
    List<BroadcastRecipientDto> recipients, int excludedCount) {
  public record BroadcastRecipientDto(Long userId, String displayName, String relationship, String location, String profilePhoto) {}
}
