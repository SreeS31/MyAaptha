package com.myaaptha.domain.presence;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.privacy.UserBlockRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PresenceService {
  private static final Duration ONLINE_WINDOW = Duration.ofSeconds(45);
  private static final Duration TYPING_WINDOW = Duration.ofSeconds(6);
  private final ConcurrentHashMap<Long, Instant> active = new ConcurrentHashMap<>();
  private final ConcurrentHashMap<String, Instant> typing = new ConcurrentHashMap<>();
  private final RelationshipRepository relationships;
  private final CircleRepository circles;
  private final UserBlockRepository blocks;
  private final UserRepository users;

  public PresenceService(RelationshipRepository relationships, CircleRepository circles,
      UserBlockRepository blocks, UserRepository users) {
    this.relationships = relationships;
    this.circles = circles;
    this.blocks = blocks;
    this.users = users;
  }

  public void heartbeat(Long userId) { active.put(userId, Instant.now()); }

  public PresenceDto direct(Long viewerId, Long otherUserId) {
    assertDirectAccess(viewerId, otherUserId);
    Instant last = active.get(otherUserId);
    boolean online = last != null && last.isAfter(Instant.now().minus(ONLINE_WINDOW));
    boolean isTyping = fresh("direct:" + viewerId + ":" + otherUserId);
    return new PresenceDto(online, last, isTyping
        ? List.of(new PresenceDto.TypingUserDto(otherUserId, name(otherUserId))) : List.of());
  }

  public void typeDirect(Long userId, Long recipientId, boolean value) {
    assertDirectAccess(userId, recipientId);
    set("direct:" + recipientId + ":" + userId, value);
    heartbeat(userId);
  }

  public PresenceDto circle(Long viewerId, Long circleId) {
    var circle = memberCircle(viewerId, circleId);
    var values = circle.getMemberUserIds().stream().filter(id -> !id.equals(viewerId))
        .filter(id -> fresh("circle:" + circleId + ":" + id))
        .map(id -> new PresenceDto.TypingUserDto(id, name(id))).toList();
    return new PresenceDto(true, active.get(viewerId), values);
  }

  public void typeCircle(Long userId, Long circleId, boolean value) {
    memberCircle(userId, circleId);
    set("circle:" + circleId + ":" + userId, value);
    heartbeat(userId);
  }

  private void set(String key, boolean value) { if (value) typing.put(key, Instant.now()); else typing.remove(key); }
  private boolean fresh(String key) {
    Instant value = typing.get(key);
    if (value == null) return false;
    if (value.isBefore(Instant.now().minus(TYPING_WINDOW))) { typing.remove(key, value); return false; }
    return true;
  }
  private void assertDirectAccess(Long first, Long second) {
    if (first.equals(second) || blocks.blockedEitherWay(first, second) ||
        (relationships.findByOwnerUserIdAndRelatedUserId(first, second).isEmpty()
            && relationships.findByOwnerUserIdAndRelatedUserId(second, first).isEmpty()))
      throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Presence is available only to connected people");
  }
  private com.myaaptha.domain.circle.model.CircleEntity memberCircle(Long userId, Long circleId) {
    var circle = circles.findById(circleId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Circle not found"));
    if (!circle.getMemberUserIds().contains(userId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only circle members can view presence");
    return circle;
  }
  private String name(Long userId) {
    var user = users.findById(userId).orElseThrow();
    String value = ((user.getFirstName() == null ? "" : user.getFirstName()) + " " +
        (user.getSurname() == null ? "" : user.getSurname())).trim();
    return value.isBlank() ? user.getUsername() : value;
  }
}
