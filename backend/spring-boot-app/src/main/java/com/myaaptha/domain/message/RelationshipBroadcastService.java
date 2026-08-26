package com.myaaptha.domain.message;

import com.myaaptha.domain.message.model.RelationshipBroadcastEntity;
import com.myaaptha.domain.network.dto.BroadcastAudienceDto;
import com.myaaptha.domain.network.dto.BroadcastAudienceDto.BroadcastRecipientDto;
import com.myaaptha.domain.network.dto.BroadcastResultDto;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class RelationshipBroadcastService {
  private static final Set<String> CHILD_TYPES = Set.of("child", "son", "daughter");
  private static final int MAX_RECIPIENTS = 500;
  private final RelationshipRepository relationships;
  private final UserRepository users;
  private final UserProfileRepository profiles;
  private final DirectMessageService directMessages;
  private final RelationshipBroadcastRepository broadcasts;

  public RelationshipBroadcastService(RelationshipRepository relationships, UserRepository users,
      UserProfileRepository profiles, DirectMessageService directMessages,
      RelationshipBroadcastRepository broadcasts) {
    this.relationships = relationships; this.users = users; this.profiles = profiles;
    this.directMessages = directMessages; this.broadcasts = broadcasts;
  }

  public BroadcastAudienceDto preview(Long senderId, String audienceType, Long anchorUserId, String location) {
    String type = normalizeType(audienceType);
    List<RelationshipEntity> owned = relationships.findByOwnerUserId(senderId);
    LinkedHashSet<Long> selected = switch (type) {
      case "HORIZONTAL" -> horizontal(senderId, owned, anchorUserId);
      case "VERTICAL" -> vertical(senderId, owned, anchorUserId);
      case "LOCATION" -> location(owned, location);
      default -> throw new IllegalStateException();
    };
    if (selected.size() > MAX_RECIPIENTS) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
        "This audience has more than " + MAX_RECIPIENTS + " people. Narrow the selection.");
    Map<Long, RelationshipEntity> byUser = new HashMap<>();
    owned.forEach(item -> byUser.put(item.getRelatedUserId(), item));
    List<BroadcastRecipientDto> recipients = new ArrayList<>();
    int excluded = 0;
    for (Long id : selected) {
      UserEntity user = users.findById(id).orElse(null);
      if (user == null || !"ACTIVE".equals(user.getAccountStatus()) || "MANAGED".equals(user.getIdentityType())) {
        excluded++; continue;
      }
      RelationshipEntity relation = byUser.get(id);
      recipients.add(new BroadcastRecipientDto(id, name(user), relation == null ? "" : relation.getType(),
          locationText(user), profiles.findById(id).map(profile -> profile.getProfilePhoto()).orElse(null)));
    }
    return new BroadcastAudienceDto(type, anchorUserId, clean(location), recipients, excluded);
  }

  public BroadcastResultDto send(Long senderId, String audienceType, Long anchorUserId, String location,
      String message, MultipartFile file) {
    BroadcastAudienceDto audience = preview(senderId, audienceType, anchorUserId, location);
    if (audience.recipients().isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
        "No active MyAaptha accounts match this audience");
    String cleanMessage = message == null ? "" : message.trim();
    if (cleanMessage.isBlank() && (file == null || file.isEmpty()))
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Write a message or choose an attachment");
    List<String> failures = new ArrayList<>();
    int delivered = 0;
    for (BroadcastRecipientDto recipient : audience.recipients()) {
      try { directMessages.send(senderId, recipient.userId(), cleanMessage, file); delivered++; }
      catch (RuntimeException exception) { failures.add(recipient.displayName() + ": " + reason(exception)); }
    }
    RelationshipBroadcastEntity record = new RelationshipBroadcastEntity();
    record.setSenderUserId(senderId); record.setAudienceType(audience.audienceType());
    record.setAnchorUserId(anchorUserId); record.setLocationQuery(clean(location));
    record.setMessagePreview(cleanMessage.length() > 500 ? cleanMessage.substring(0, 500) : cleanMessage);
    record.setRecipientCount(delivered); record.setFailedCount(failures.size()); record = broadcasts.save(record);
    return new BroadcastResultDto(record.getId(), record.getAudienceType(), delivered,
        failures.size(), failures, record.getCreatedAt());
  }

  private LinkedHashSet<Long> horizontal(Long senderId, List<RelationshipEntity> owned, Long anchor) {
    if (anchor == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose the parent node");
    assertAnchor(senderId, owned, anchor);
    LinkedHashSet<Long> result = new LinkedHashSet<>();
    for (RelationshipEntity item : owned) {
      boolean anchored = anchor.equals(senderId) ? item.getRelativeToUserId() == null : anchor.equals(item.getRelativeToUserId());
      if (anchored && item.getType() != null && CHILD_TYPES.contains(item.getType().toLowerCase())) result.add(item.getRelatedUserId());
    }
    return result;
  }

  private LinkedHashSet<Long> vertical(Long senderId, List<RelationshipEntity> owned, Long anchor) {
    if (anchor == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose the starting node");
    assertAnchor(senderId, owned, anchor);
    LinkedHashSet<Long> result = new LinkedHashSet<>();
    ArrayDeque<Long> queue = new ArrayDeque<>(); queue.add(anchor);
    while (!queue.isEmpty()) {
      Long current = queue.removeFirst();
      if (!current.equals(senderId)) result.add(current);
      for (RelationshipEntity item : owned) if (current.equals(item.getRelativeToUserId()) && result.add(item.getRelatedUserId())) queue.add(item.getRelatedUserId());
    }
    return result;
  }

  private LinkedHashSet<Long> location(List<RelationshipEntity> owned, String query) {
    String needle = clean(query);
    if (needle == null || needle.length() < 2) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter at least two location characters");
    needle = needle.toLowerCase(); LinkedHashSet<Long> result = new LinkedHashSet<>();
    for (RelationshipEntity item : owned) {
      UserEntity user = users.findById(item.getRelatedUserId()).orElse(null);
      if (user != null && locationText(user).toLowerCase().contains(needle)) result.add(user.getId());
    }
    return result;
  }

  private void assertAnchor(Long senderId, List<RelationshipEntity> owned, Long anchor) {
    if (!anchor.equals(senderId) && owned.stream().noneMatch(item -> anchor.equals(item.getRelatedUserId())))
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a person from your relationship tree");
  }
  private String normalizeType(String value) { String type = clean(value); if (type == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose an audience type"); type = type.toUpperCase(); if (!Set.of("HORIZONTAL","VERTICAL","LOCATION").contains(type)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported audience type"); return type; }
  private String locationText(UserEntity user) { var profile = profiles.findById(user.getId()).orElse(null); return String.join(" ", values(user.getLocation(), profile == null ? null : profile.getAddressLine1(), profile == null ? null : profile.getAddressLine2(), profile == null ? null : profile.getCity(), profile == null ? null : profile.getState(), profile == null ? null : profile.getPostalCode(), profile == null ? null : profile.getCountry(), profile == null ? null : profile.getWorkLocation())); }
  private String[] values(String... values) { return Arrays.stream(values).filter(Objects::nonNull).filter(v -> !v.isBlank()).toArray(String[]::new); }
  private String name(UserEntity user) { String value = ((user.getFirstName()==null?"":user.getFirstName())+" "+(user.getSurname()==null?"":user.getSurname())).trim(); return value.isBlank()?user.getUsername():value; }
  private String clean(String value) { return value == null || value.isBlank() ? null : value.trim(); }
  private String reason(RuntimeException exception) { if (exception instanceof ResponseStatusException response && response.getReason()!=null) return response.getReason(); return "delivery failed"; }
}
