package com.myaaptha.domain.presence;

import java.time.Instant;
import java.util.List;

public record PresenceDto(boolean online, Instant lastActiveAt, List<TypingUserDto> typingUsers) {
  public record TypingUserDto(Long userId, String displayName) {}
}
