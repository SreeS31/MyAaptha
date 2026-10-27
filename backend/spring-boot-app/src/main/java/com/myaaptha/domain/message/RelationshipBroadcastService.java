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
    return preview(senderId,audienceType,anchorUserId,location,null);
  }

  public BroadcastAudienceDto preview(Long senderId, String audienceType, Long anchorUserId, String location, Integer levels) {
    if(levels != null && (levels < 1 || levels > 10)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose between 1 and 10 levels");
    String type = normalizeType(audienceType);
    List<RelationshipEntity> owned = relationships.findByOwnerUserId(senderId);
    LinkedHashSet<Long> selected = switch (type) {
      case "HORIZONTAL" -> selectTree(senderId, owned, anchorUserId, levels == null ? 1 : levels, true);
      case "VERTICAL" -> selectTree(senderId, owned, anchorUserId, levels, false);
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
    return send(senderId,audienceType,anchorUserId,location,message,file,null);
  }

  public BroadcastResultDto send(Long senderId,String audienceType,Long anchorUserId,String location,String message,MultipartFile file,Integer levels) {
    BroadcastAudienceDto audience = preview(senderId, audienceType, anchorUserId, location,levels);
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

  // Traverse only edges owned by the sender. A visited set prevents cycles and duplicate delivery.
  private LinkedHashSet<Long> selectTree(Long senderId,List<RelationshipEntity> owned,Long anchor,Integer levels,boolean exactLevel) {
    if(anchor==null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose the starting person");
    assertAnchor(senderId,owned,anchor);
    Map<Long,List<Long>> children=new LinkedHashMap<>();
    for(var edge:owned){
      if(exactLevel&&(edge.getType()==null||!CHILD_TYPES.contains(edge.getType().toLowerCase(Locale.ROOT)))) continue;
      Long parent=edge.getRelativeToUserId()==null?senderId:edge.getRelativeToUserId();
      children.computeIfAbsent(parent,key->new ArrayList<>()).add(edge.getRelatedUserId());
    }
    record Node(Long id,int depth){}
    var queue=new ArrayDeque<Node>();queue.add(new Node(anchor,0));
    var visited=new HashSet<Long>();visited.add(anchor);visited.add(senderId);
    var result=new LinkedHashSet<Long>();
    while(!queue.isEmpty()){
      var current=queue.removeFirst();
      if(!current.id().equals(senderId)&&(!exactLevel||current.depth()==levels))result.add(current.id());
      if(levels!=null&&current.depth()>=levels)continue;
      for(Long child:children.getOrDefault(current.id(),List.of()))if(visited.add(child))queue.add(new Node(child,current.depth()+1));
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
