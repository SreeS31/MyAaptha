package com.myaaptha.domain.presence;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.privacy.UserBlockRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PresenceService {
  private static final Duration ONLINE_WINDOW = Duration.ofSeconds(45);
  private static final Duration TYPING_WINDOW = Duration.ofSeconds(6);
  private final com.myaaptha.platform.state.EphemeralState state;
  private final RelationshipRepository relationships;
  private final CircleRepository circles;
  private final UserBlockRepository blocks;
  private final UserRepository users;

  public PresenceService(RelationshipRepository relationships, CircleRepository circles,
      UserBlockRepository blocks, UserRepository users, com.myaaptha.platform.state.EphemeralState state) {
    this.state = state;
    this.relationships = relationships;
    this.circles = circles;
    this.blocks = blocks;
    this.users = users;
  }

  public void heartbeat(Long userId) { state.put("presence:"+userId, Instant.now().toString(), Duration.ofMinutes(5)); }

  public PresenceDto direct(Long viewerId, Long otherUserId) {
    assertDirectAccess(viewerId, otherUserId);
    Instant last = lastActive(otherUserId);
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

  @org.springframework.transaction.annotation.Transactional(readOnly=true)
  public PresenceDto circle(Long viewerId, Long circleId) {
    var circle = memberCircle(viewerId, circleId);
    var members=circle.getMemberUserIds().stream().filter(id -> !id.equals(viewerId)).toList();
    var flags=state.getAll(members.stream().map(id -> "typing:circle:"+circleId+":"+id).toList());
    var values=new java.util.ArrayList<PresenceDto.TypingUserDto>();
    for(int i=0;i<members.size();i++)if(flags.get(i)!=null)values.add(new PresenceDto.TypingUserDto(members.get(i),name(members.get(i))));
    return new PresenceDto(true, lastActive(viewerId), values);
  }

  @org.springframework.transaction.annotation.Transactional(readOnly=true)
  public void typeCircle(Long userId, Long circleId, boolean value) {
    memberCircle(userId, circleId);
    set("circle:" + circleId + ":" + userId, value);
    heartbeat(userId);
  }

  private Instant lastActive(Long userId) { String value=state.get("presence:"+userId);return value==null?null:Instant.parse(value); }
  private void set(String key,boolean value) { if(value)state.put("typing:"+key,"1",TYPING_WINDOW);else state.delete("typing:"+key); }
  private boolean fresh(String key) { return state.get("typing:"+key)!=null; }
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
