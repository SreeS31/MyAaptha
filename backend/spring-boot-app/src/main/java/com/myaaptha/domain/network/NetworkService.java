package com.myaaptha.domain.network;

import java.util.List;
import java.util.Set;
import java.util.LinkedHashSet;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.UUID;
import java.util.LinkedHashMap;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.circle.model.CircleEntity;
import com.myaaptha.domain.network.dto.AddRelationshipRequest;
import com.myaaptha.domain.network.dto.AddPersonRequest;
import com.myaaptha.domain.network.dto.CreateNetworkCircleRequest;
import com.myaaptha.domain.network.dto.NetworkCircleDto;
import com.myaaptha.domain.network.dto.NetworkCircleMemberDto;
import com.myaaptha.domain.network.dto.NetworkPersonDto;
import com.myaaptha.domain.network.dto.NetworkRelationshipDto;
import com.myaaptha.domain.network.dto.UpdateRelationshipRequest;
import com.myaaptha.domain.network.dto.UpdateNetworkCircleRequest;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import com.myaaptha.domain.notification.NotificationCommand;
import com.myaaptha.domain.notification.NotificationService;
import com.myaaptha.domain.privacy.UserBlockRepository;

@Service
@Transactional
public class NetworkService {
  private static final Set<String> RELATIONSHIP_TYPES = Set.of(
      "Mother", "Father", "Wife", "Husband", "Son", "Daughter", "Brother", "Sister",
      "Grandmother", "Grandfather", "Granddaughter", "Grandson", "Aunt", "Uncle",
      "Niece", "Nephew", "Cousin", "Guardian", "Relative", "Friend", "Colleague", "Other");
  private static final Set<String> VISIBILITY_SCOPES = Set.of("PUBLIC", "FRIENDS", "RELATIVES", "COLLEAGUES");
  private static final Set<String> RELATIVE_TYPES = Set.of("wife", "husband", "mother", "father",
      "son", "daughter", "sister", "brother", "grandmother", "grandfather", "granddaughter",
      "grandson", "aunt", "uncle", "niece", "nephew", "cousin", "guardian", "relative");

  private final UserRepository userRepository;
  private final RelationshipRepository relationshipRepository;
  private final CircleRepository circleRepository;
  private final PasswordEncoder passwordEncoder;
  private final UserProfileRepository profileRepository;
  private final NotificationService notificationService;
  private final UserBlockRepository blockRepository;

  public NetworkService(UserRepository userRepository, RelationshipRepository relationshipRepository,
      CircleRepository circleRepository, PasswordEncoder passwordEncoder, UserProfileRepository profileRepository,
      NotificationService notificationService, UserBlockRepository blockRepository) {
    this.userRepository = userRepository;
    this.relationshipRepository = relationshipRepository;
    this.circleRepository = circleRepository;
    this.passwordEncoder = passwordEncoder;
    this.profileRepository = profileRepository;
    this.notificationService = notificationService;
    this.blockRepository = blockRepository;
  }

  @Transactional(readOnly = true)
  public List<NetworkPersonDto> search(Long currentUserId, String query) {
    String normalizedQuery = query == null ? "" : query.trim().toLowerCase();
    LinkedHashMap<Long, UserEntity> matches = new LinkedHashMap<>();
    if(!normalizedQuery.isBlank())userRepository.searchPeople(currentUserId, normalizedQuery,org.springframework.data.domain.PageRequest.of(0,200)).forEach(user -> matches.put(user.getId(), user));
    List<RelationshipEntity> ownedRelationships = relationshipRepository.findByOwnerUserId(currentUserId);
    ownedRelationships.stream()
        .map(RelationshipEntity::getRelatedUserId).filter(id -> id != null)
        .map(this::requireUser).filter(user -> matchesSearch(user, normalizedQuery, ownedRelationships))
        .forEach(user -> matches.putIfAbsent(user.getId(), user));
    return matches.values().stream().filter(user -> !blockRepository.blockedEitherWay(currentUserId,user.getId())).filter(user -> isVisibleTo(currentUserId, user.getId())).limit(50)
        .map(user -> toPerson(user, relationshipName(ownedRelationships, user.getId()))).toList();
  }

  @Transactional(readOnly = true)
  public List<NetworkRelationshipDto> relationships(Long currentUserId) {
    var owned = relationshipRepository.findByOwnerUserId(currentUserId);
    if (owned.isEmpty()) return List.of();
    var ids = owned.stream().map(RelationshipEntity::getRelatedUserId).filter(java.util.Objects::nonNull).distinct().toList();
    var people = new LinkedHashMap<Long, UserEntity>();
    var profiles = new LinkedHashMap<Long, UserProfileEntity>();
    // Bound IN-list sizes and avoid per-person queries for large networks.
    for (int offset = 0; offset < ids.size(); offset += 500) {
      var batch = ids.subList(offset, Math.min(ids.size(), offset + 500));
      userRepository.findAllById(batch).forEach(person -> people.put(person.getId(), person));
      profileRepository.findAllById(batch).forEach(profile -> profiles.put(profile.getUserId(), profile));
    }
    return owned.stream().map(entity -> {
      var person = people.get(entity.getRelatedUserId());
      if (person == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Related person is unavailable");
      return relationshipDto(entity, person, profiles.get(person.getId()));
    }).toList();
  }

  @Transactional(readOnly = true)
  public List<String> relationshipTypes() {
    return RELATIONSHIP_TYPES.stream().sorted(String.CASE_INSENSITIVE_ORDER).toList();
  }

  public NetworkRelationshipDto addRelationship(Long currentUserId, AddRelationshipRequest request) {
    if (request.relatedUserId() == null || currentUserId.equals(request.relatedUserId())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose another user");
    }
    UserEntity related = requireUser(request.relatedUserId());
    if(blockRepository.blockedEitherWay(currentUserId,related.getId()))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Person is unavailable");
    String type = normalizeRelationshipType(request.type());
    RelationshipEntity relationship = relationshipRepository
        .findByOwnerUserIdAndRelatedUserId(currentUserId, related.getId())
        .orElseGet(RelationshipEntity::new);
    relationship.setOwnerUserId(currentUserId);
    relationship.setRelatedUserId(related.getId());
    relationship.setType(type);
    relationship.setMilestoneDate(cleanDate(request.milestoneDate(), "Relationship date"));
    relationship.setRelatedBirthDate(cleanDate(request.dateOfBirth(), "Date of birth"));
    relationship.setRelatedDeathDate(cleanDate(request.dateOfDeath(), "Date of death"));
    relationship.setContactName(profileDisplayName(related));
    // Linking a public profile does not grant access to private login identifiers.
    applyVisibility(currentUserId, relationship, request.visibilityScope(), request.visibilityCompany());
    relationship = relationshipRepository.save(relationship);
    UserEntity owner=requireUser(currentUserId);
    notificationService.notify(new NotificationCommand(related.getId(),"RELATIONSHIP","New relationship",profileDisplayName(owner)+" added you as "+type,"/dashboard","RELATIONSHIP",relationship.getId()));
    return relationshipDto(relationship, related);
  }

  public NetworkRelationshipDto addPerson(Long currentUserId, AddPersonRequest request) {
    String fullName = requireText(request.fullName(), "Full name");
    String type = normalizeRelationshipType(request.type());
    String identityType = request.identityType() == null || request.identityType().isBlank()
        ? (request.managedCategory() == null || request.managedCategory().isBlank() ? "ACCOUNT" : "MANAGED")
        : request.identityType().trim().toUpperCase();
    if (!Set.of("ACCOUNT", "MANAGED").contains(identityType)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported person type");
    }

    String phoneNumber = request.phoneNumber() == null || request.phoneNumber().isBlank()
        ? null : normalizePhoneNumber(request.phoneNumber());
    UserEntity person;
    if ("MANAGED".equals(identityType)) {
      String category = requireText(request.managedCategory(), "Managed person category").toUpperCase();
      if (!Set.of("CHILD", "MEMORIAL", "OTHER").contains(category)) {
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported managed person category");
      }
      UserEntity managed = new UserEntity();
      managed.setUsername("managed_" + UUID.randomUUID().toString().replace("-", ""));
      managed.setFirstName(fullName);
      managed.setPasswordHash(passwordEncoder.encode(UUID.randomUUID().toString()));
      managed.setRole("USER");
      managed.setAccountStatus("MANAGED");
      managed.setIdentityType("MANAGED");
      managed.setManagedCategory(category);
      managed.setGuardianUserId(currentUserId);
      managed.setClaimStatus("MEMORIAL".equals(category) ? "NOT_CLAIMABLE" : "GUARDIAN_APPROVAL_REQUIRED");
      managed.setManagedDateOfBirth(cleanDate(request.dateOfBirth(), "Date of birth"));
      managed.setManagedDateOfDeath(cleanDate(request.dateOfDeath(), "Date of death"));
      managed.setManagedNotes(request.notes() == null || request.notes().isBlank() ? null : request.notes().trim());
      person = userRepository.save(managed);
    } else {
      if (phoneNumber == null) {
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mobile number is required for a MyAaptha account");
      }
      final String accountPhone = phoneNumber;
      person = userRepository.findByPhoneNumber(accountPhone).orElseGet(() -> {
      UserEntity invited = new UserEntity();
      invited.setUsername("invite_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16));
      invited.setFirstName(fullName);
      invited.setPhoneNumber(accountPhone);
      invited.setEmail(request.email() == null || request.email().isBlank() ? null : request.email().trim().toLowerCase());
      invited.setPasswordHash(passwordEncoder.encode(UUID.randomUUID().toString()));
      invited.setRole("USER");
      invited.setAccountStatus("INVITED");
      invited.setIdentityType("ACCOUNT");
      return userRepository.save(invited);
      });
    }
    if (currentUserId.equals(person.getId())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "You cannot add yourself");
    }
    Long relativeToUserId = request.relativeToUserId();
    if(blockRepository.blockedEitherWay(currentUserId,person.getId()))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Person is unavailable");
    if (relativeToUserId != null) {
      if (relativeToUserId.equals(person.getId())) {
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "A person cannot be related to themselves");
      }
      relationshipRepository.findByOwnerUserIdAndRelatedUserId(currentUserId, relativeToUserId)
          .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a person from your relationships"));
    }
    RelationshipEntity relationship = relationshipRepository
        .findByOwnerUserIdAndRelatedUserId(currentUserId, person.getId()).orElseGet(RelationshipEntity::new);
    relationship.setOwnerUserId(currentUserId);
    relationship.setRelatedUserId(person.getId());
    relationship.setRelativeToUserId(relativeToUserId);
    relationship.setType(type);
    relationship.setMilestoneDate(cleanDate(request.milestoneDate(), "Relationship date"));
    relationship.setRelatedBirthDate(cleanDate(request.dateOfBirth(), "Date of birth"));
    relationship.setRelatedDeathDate(cleanDate(request.dateOfDeath(), "Date of death"));
    relationship.setContactName(fullName);
    relationship.setContactPhone(phoneNumber);
    relationship.setContactEmail(cleanEmail(request.email()));
    applyVisibility(currentUserId, relationship, request.visibilityScope(), request.visibilityCompany());
    relationship = relationshipRepository.save(relationship);
    if("ACCOUNT".equals(identityType)){
      UserEntity owner=requireUser(currentUserId);
      String notificationType="INVITED".equals(person.getAccountStatus())?"INVITATION":"RELATIONSHIP";
      String title="INVITATION".equals(notificationType)?"Join MyAaptha":"New relationship";
      notificationService.notify(new NotificationCommand(person.getId(),notificationType,title,profileDisplayName(owner)+" added you as "+type,"/dashboard","RELATIONSHIP",relationship.getId()));
    }
    return relationshipDto(relationship, person);
  }

  public void removeRelationship(Long currentUserId, Long relationshipId) {
    RelationshipEntity entity = relationshipRepository.findById(relationshipId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Relationship not found"));
    if (!currentUserId.equals(entity.getOwnerUserId())) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this relationship");
    }
    circleRepository.findByOwnerUserId(currentUserId).forEach(circle -> {
      if (circle.getMemberUserIds().remove(entity.getRelatedUserId())) circleRepository.save(circle);
    });
    relationshipRepository.delete(entity);
  }

  public NetworkRelationshipDto updateRelationship(Long currentUserId, Long relationshipId, UpdateRelationshipRequest request) {
    RelationshipEntity relationship = relationshipRepository.findById(relationshipId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Relationship not found"));
    if (!currentUserId.equals(relationship.getOwnerUserId())) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You do not own this relationship");
    }
    relationship.setContactName(requireText(request.contactName(), "Person name"));
    relationship.setContactPhone(request.contactPhone() == null || request.contactPhone().isBlank()
        ? null : normalizePhoneNumber(request.contactPhone()));
    relationship.setContactEmail(cleanEmail(request.contactEmail()));
    relationship.setType(normalizeRelationshipType(request.type()));
    relationship.setMilestoneDate(cleanDate(request.milestoneDate(), "Relationship date"));
    relationship.setRelatedBirthDate(cleanDate(request.dateOfBirth(), "Date of birth"));
    relationship.setRelatedDeathDate(cleanDate(request.dateOfDeath(), "Date of death"));
    applyVisibility(currentUserId, relationship, request.visibilityScope(), request.visibilityCompany());
    relationship = relationshipRepository.save(relationship);
    return relationshipDto(relationship, requireUser(relationship.getRelatedUserId()));
  }

  @Transactional(readOnly = true)
  public List<NetworkCircleDto> circles(Long currentUserId) {
    return toCircles(circleRepository.findVisibleToUser(currentUserId), currentUserId);
  }

  public NetworkCircleDto createCircle(Long currentUserId, CreateNetworkCircleRequest request) {
    String name = requireText(request.name(), "Circle name");
    CircleEntity entity = new CircleEntity();
    entity.setName(name);
    entity.setDescription(request.description() == null || request.description().isBlank() ? "Circle conversation" : request.description().trim());
    entity.setOwnerUserId(currentUserId);
    entity.getMemberUserIds().add(currentUserId);
    entity.getAdminUserIds().add(currentUserId);
    return toCircle(circleRepository.save(entity), currentUserId);
  }

  public NetworkCircleDto updateCircle(Long currentUserId, Long circleId, UpdateNetworkCircleRequest request) {
    CircleEntity circle = administeredCircle(currentUserId, circleId);
    circle.setName(requireText(request.name(), "Circle name"));
    circle.setDescription(request.description() == null || request.description().isBlank() ? "Circle conversation" : request.description().trim());
    String postingPermission=request.postingPermission()==null?circle.getPostingPermission():request.postingPermission().trim().toUpperCase();
    if (!Set.of("ALL_MEMBERS","ADMINS_ONLY").contains(postingPermission)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose who can post in this circle");
    circle.setPostingPermission(postingPermission);
    return toCircle(circleRepository.save(circle), currentUserId);
  }

  public NetworkCircleDto addCircleMember(Long currentUserId, Long circleId, Long userId) {
    CircleEntity circle = administeredCircle(currentUserId, circleId);
    requireUser(userId);
    if (relationshipRepository.findByOwnerUserIdAndRelatedUserId(currentUserId, userId).isEmpty()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Add this person as a relationship before adding them to a circle");
    }
    circle.getMemberUserIds().add(userId);
    circle=circleRepository.save(circle);
    notificationService.notify(new NotificationCommand(userId,"INVITATION","Added to "+circle.getName(),profileDisplayName(requireUser(currentUserId))+" added you to this circle","/dashboard?circleId="+circleId,"CIRCLE",circleId));
    return toCircle(circle, currentUserId);
  }

  public NetworkCircleDto removeCircleMember(Long currentUserId, Long circleId, Long userId) {
    CircleEntity circle = administeredCircle(currentUserId, circleId);
    if (userId.equals(circle.getOwnerUserId())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The circle creator cannot be removed");
    }
    circle.getMemberUserIds().remove(userId);
    circle.getAdminUserIds().remove(userId);
    return toCircle(circleRepository.save(circle), currentUserId);
  }

  public NetworkCircleDto promoteCircleAdmin(Long currentUserId, Long circleId, Long userId) {
    CircleEntity circle = administeredCircle(currentUserId, circleId);
    if (!circle.getMemberUserIds().contains(userId)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only circle members can become admins");
    }
    UserEntity member = requireUser(userId);
    if (!"ACTIVE".equals(member.getAccountStatus()) || "MANAGED".equals(member.getIdentityType())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only active MyAaptha accounts with their own login can become admins");
    }
    circle.getAdminUserIds().add(userId);
    return toCircle(circleRepository.save(circle), currentUserId);
  }

  public NetworkCircleDto demoteCircleAdmin(Long currentUserId, Long circleId, Long userId) {
    CircleEntity circle = administeredCircle(currentUserId, circleId);
    if (userId.equals(circle.getOwnerUserId())) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The circle creator is a permanent admin");
    }
    circle.getAdminUserIds().remove(userId);
    return toCircle(circleRepository.save(circle), currentUserId);
  }

  private CircleEntity administeredCircle(Long userId, Long circleId) {
    CircleEntity circle = circleRepository.findById(circleId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Circle not found"));
    if (!circle.getAdminUserIds().contains(userId)) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only circle admins can manage members");
    }
    return circle;
  }

  private UserEntity requireUser(Long id) {
    return userRepository.findById(id)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
  }

  private NetworkCircleDto toCircle(CircleEntity circle, Long currentUserId) {
    return toCircles(List.of(circle), currentUserId).getFirst();
  }

  private List<NetworkCircleDto> toCircles(List<CircleEntity> circles, Long currentUserId) {
    if (circles.isEmpty()) return List.of();
    var ids = new LinkedHashSet<Long>();
    var ownerIds = new LinkedHashSet<Long>();
    for (var circle : circles) {
      ids.addAll(circle.getMemberUserIds());
      ids.add(circle.getOwnerUserId());
      ownerIds.add(circle.getOwnerUserId());
    }
    var people = new LinkedHashMap<Long, UserEntity>();
    var profiles = new LinkedHashMap<Long, UserProfileEntity>();
    var names = new java.util.HashMap<Long, java.util.Map<Long, String>>();
    var allIds = List.copyOf(ids);
    var owners = List.copyOf(ownerIds);
    for (int offset = 0; offset < allIds.size(); offset += 500) {
      var batch = allIds.subList(offset, Math.min(allIds.size(), offset + 500));
      userRepository.findAllById(batch).forEach(user -> people.put(user.getId(), user));
      profileRepository.findAllById(batch).forEach(profile -> profiles.put(profile.getUserId(), profile));
      for (int start = 0; start < owners.size(); start += 100) {
        var ownerBatch = owners.subList(start, Math.min(owners.size(), start + 100));
        for (var relation : relationshipRepository.findByOwnerUserIdInAndRelatedUserIdIn(ownerBatch, batch)) {
          String name = relation.getContactName();
          if (name != null && !name.isBlank()) names.computeIfAbsent(relation.getOwnerUserId(), key -> new java.util.HashMap<>())
              .putIfAbsent(relation.getRelatedUserId(), name);
        }
      }
    }
    return circles.stream().map(circle -> {
      var owner = people.get(circle.getOwnerUserId());
      if (owner == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Circle owner is unavailable");
      var contactNames = names.getOrDefault(circle.getOwnerUserId(), java.util.Map.of());
      var members = circle.getMemberUserIds().stream().map(id -> {
        var user = people.get(id);
        if (user == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Circle member is unavailable");
        return new NetworkCircleMemberDto(toPerson(user, contactNames.get(id), profiles.get(id)),
            circle.getAdminUserIds().contains(id), circle.getOwnerUserId().equals(id));
      }).toList();
      var profile = profiles.get(circle.getOwnerUserId());
      return new NetworkCircleDto(circle.getId(), circle.getName(), circle.getDescription(), members,
          profileDisplayName(owner), profile == null ? null : profile.getProfilePhoto(),
          currentUserId.equals(circle.getOwnerUserId()), circle.getAdminUserIds().contains(currentUserId),
          circle.getPostingPermission(), "ALL_MEMBERS".equals(circle.getPostingPermission()) || circle.getAdminUserIds().contains(currentUserId));
    }).toList();
  }

  private NetworkPersonDto toPerson(UserEntity user) { return toPerson(user, null); }

  private NetworkPersonDto toPerson(UserEntity user, String contactName) {
    return toPerson(user, contactName, profileRepository.findById(user.getId()).orElse(null));
  }

  private NetworkPersonDto toPerson(UserEntity user, String contactName, UserProfileEntity profile) {
    String displayName = String.join(" ",
        user.getFirstName() == null ? "" : user.getFirstName(),
        user.getSurname() == null ? "" : user.getSurname()).trim();
    if (contactName != null && !contactName.isBlank()) displayName = contactName.trim();
    if (displayName.isBlank()) displayName = profileDisplayName(user);
    String gender = profile == null ? null : profile.getGender();
    return new NetworkPersonDto(user.getId(), user.getFirstName(), user.getSurname(),
        displayName, null, user.getLocation(), user.getAccountStatus(),
        profile == null ? null : profile.getProfilePhoto(),
        user.getIdentityType(), user.getManagedCategory(), user.getClaimStatus(), gender);
  }

  private NetworkRelationshipDto relationshipDto(RelationshipEntity relationship, UserEntity person) {
    return relationshipDto(relationship, person, profileRepository.findById(person.getId()).orElse(null));
  }

  private NetworkRelationshipDto relationshipDto(RelationshipEntity relationship, UserEntity person, UserProfileEntity profile) {
    String profileBirth=profile == null ? null : profile.getDateOfBirth();
    String birth=profileBirth!=null&&!profileBirth.isBlank()?profileBirth:(person.getManagedDateOfBirth()!=null?person.getManagedDateOfBirth():relationship.getRelatedBirthDate());
    String death=person.getManagedDateOfDeath()!=null?person.getManagedDateOfDeath():relationship.getRelatedDeathDate();
    return new NetworkRelationshipDto(relationship.getId(), relationship.getType(), relationship.getVisibilityScope(), relationship.getContactPhone(), relationship.getContactEmail(),
        relationship.getVisibilityCompany(), relationship.getRelativeToUserId(), relationship.getMilestoneDate(), birth, death, toPerson(person, relationship.getContactName(), profile));
  }

  private String cleanEmail(String email) {
    if (email == null || email.isBlank()) return null;
    String value = email.trim().toLowerCase();
    if (!value.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid email address");
    }
    return value;
  }

  private String cleanDate(String date, String label) {
    if (date == null || date.isBlank()) return null;
    try {
      return LocalDate.parse(date.trim()).toString();
    } catch (DateTimeParseException exception) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, label + " must be a valid date");
    }
  }

  private void applyVisibility(Long ownerUserId, RelationshipEntity relationship, String requestedScope, String requestedCompany) {
    String scope = requestedScope == null || requestedScope.isBlank() ? "FRIENDS" : requestedScope.trim().toUpperCase();
    if (!VISIBILITY_SCOPES.contains(scope)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported view setting");
    }
    relationship.setVisibilityScope(scope);
    if (!"COLLEAGUES".equals(scope)) {
      relationship.setVisibilityCompany(null);
      return;
    }
    String company = requireText(requestedCompany, "Company");
    boolean belongsToOwner = employmentCompanies(ownerUserId).stream().anyMatch(item -> item.equalsIgnoreCase(company));
    if (!belongsToOwner) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a company saved in your employment profile");
    }
    relationship.setVisibilityCompany(company);
  }

  private boolean isVisibleTo(Long viewerId, Long targetId) {
    if (viewerId.equals(targetId) || relationshipRepository.findByOwnerUserIdAndRelatedUserId(viewerId, targetId).isPresent()) return true;
    for (RelationshipEntity share : relationshipRepository.findByRelatedUserId(targetId)) {
      String scope = share.getVisibilityScope() == null ? "FRIENDS" : share.getVisibilityScope();
      if ("PUBLIC".equalsIgnoreCase(scope)) return true;
      if (share.getOwnerUserId() == null) continue;
      RelationshipEntity audience = relationshipRepository.findByOwnerUserIdAndRelatedUserId(share.getOwnerUserId(), viewerId).orElse(null);
      if (audience == null) continue;
      if ("FRIENDS".equalsIgnoreCase(scope) && "Friend".equalsIgnoreCase(audience.getType())) return true;
      if ("RELATIVES".equalsIgnoreCase(scope) && audience.getType() != null
          && RELATIVE_TYPES.contains(audience.getType().toLowerCase())) return true;
      if ("COLLEAGUES".equalsIgnoreCase(scope) && share.getVisibilityCompany() != null
          && employmentCompanies(viewerId).stream().anyMatch(company -> company.equalsIgnoreCase(share.getVisibilityCompany()))) return true;
    }
    return false;
  }

  private List<String> employmentCompanies(Long userId) {
    return profileRepository.findById(userId).map(UserProfileEntity::getEmployer).stream()
        .filter(value -> value != null && !value.isBlank())
        .flatMap(value -> java.util.Arrays.stream(value.split("[,;|\\n]")))
        .map(String::trim).filter(value -> !value.isBlank()).distinct().toList();
  }

  private String normalizeRelationshipType(String type) {
    String value = requireText(type, "Relationship type");
    return relationshipTypes().stream().filter(item -> item.equalsIgnoreCase(value)).findFirst()
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported relationship type"));
  }

  private String requireText(String value, String label) {
    if (value == null || value.isBlank()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, label + " is required");
    return value.trim();
  }

  private String normalizePhoneNumber(String value) {
    String phone = requireText(value, "Mobile number").replaceAll("[\\s()-]", "");
    if (!phone.matches("\\+?[0-9]{7,15}")) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mobile number must contain 7 to 15 digits");
    }
    return phone;
  }

  private boolean matchesSearch(UserEntity user, String query, List<RelationshipEntity> relationships) {
    if (query.isBlank()) return true;
    return java.util.stream.Stream.of(relationshipName(relationships, user.getId()), user.getFirstName(), user.getSurname(), user.getLocation(), user.getPhoneNumber())
        .filter(value -> value != null).anyMatch(value -> value.toLowerCase().contains(query));
  }

  private String relationshipName(List<RelationshipEntity> relationships, Long userId) {
    return relationships.stream().filter(item -> userId.equals(item.getRelatedUserId()))
        .map(RelationshipEntity::getContactName).filter(name -> name != null && !name.isBlank())
        .findFirst().orElse(null);
  }

  private String profileDisplayName(UserEntity user) {
    String name = String.join(" ", user.getFirstName() == null ? "" : user.getFirstName(),
        user.getSurname() == null ? "" : user.getSurname()).trim();
    if (!name.isBlank()) return name;
    String username = user.getUsername();
    return username == null || username.isBlank() ? "MyAaptha member"
        : username.substring(0, 1).toUpperCase() + username.substring(1);
  }
}
