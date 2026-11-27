package com.myaaptha.domain.ai;

import com.myaaptha.domain.ai.ContactOrganizerController.AcceptedContactSuggestion;
import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.AddPersonRequest;
import com.myaaptha.domain.network.dto.CreateNetworkCircleRequest;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ContactOrganizerService {
  private final NetworkService network;
  private final CircleRepository circles;

  public ContactOrganizerService(NetworkService network, CircleRepository circles) {
    this.network = network;
    this.circles = circles;
  }

  @Transactional
  public AcceptResult accept(Long userId, List<AcceptedContactSuggestion> suggestions) {
    int peopleAdded = 0;
    int membershipsAdded = 0;
    List<String> skipped = new ArrayList<>();
    Map<String,Set<Long>> circlePeople=new LinkedHashMap<>();Map<String,String> names=new LinkedHashMap<>();
    if (suggestions == null) return new AcceptResult(0, 0, skipped);
    for (AcceptedContactSuggestion suggestion : suggestions) {
      if (suggestion == null || !suggestion.selected()) continue;
      boolean hasPhone = suggestion.phone() != null && !suggestion.phone().isBlank();
      boolean hasEmail = suggestion.email() != null && !suggestion.email().isBlank();
      if (!hasPhone && !hasEmail) {
        skipped.add(suggestion.displayName() + ": no mobile number or email address");
        continue;
      }
      try {
        var relationship = network.addPerson(userId, new AddPersonRequest(
            suggestion.displayName(), suggestion.phone(), suggestion.email(), suggestion.relationship(),
            "FRIENDS", null, hasPhone ? "ACCOUNT" : "MANAGED", hasPhone ? null : "OTHER", null, null, null,
            "Added from the optional AI contact organizer after user confirmation", null));
        peopleAdded++;
        if (suggestion.circles() == null) continue;
        for (String proposedName : suggestion.circles()) {
          if (proposedName == null || proposedName.isBlank()) continue;
          String circleName = proposedName.trim();
          if(circleName.length()>100||circleName.chars().anyMatch(Character::isISOControl))continue;
          String key=circleName.replaceAll("\\s+"," ").toLowerCase(Locale.ROOT);names.putIfAbsent(key,circleName);
          circlePeople.computeIfAbsent(key,ignored->new LinkedHashSet<>()).add(relationship.person().id());
        }
      } catch (RuntimeException exception) {
        skipped.add(suggestion.displayName() + ": " + readable(exception));
      }
    }
    for(var group:circlePeople.entrySet()){
      String circleName=names.get(group.getKey());
      var existing=circles.findByOwnerUserId(userId).stream().filter(circle->circle.getName().equalsIgnoreCase(circleName)).findFirst();
      if(existing.isEmpty()&&group.getValue().size()<3)continue;
      var circle=existing.map(value->network.circles(userId).stream().filter(dto->dto.id().equals(value.getId())).findFirst().orElseThrow()).orElseGet(()->network.createCircle(userId,new CreateNetworkCircleRequest(circleName,"Suggested by the AI contact organizer")));
      for(long person:group.getValue()){network.addCircleMember(userId,circle.id(),person);membershipsAdded++;}
    }
    return new AcceptResult(peopleAdded, membershipsAdded, skipped);
  }

  private String readable(RuntimeException exception) {
    if (exception instanceof org.springframework.web.server.ResponseStatusException response
        && response.getReason() != null) return response.getReason();
    return "could not be added";
  }

  public record AcceptResult(int peopleAdded, int circleMembershipsAdded, List<String> skipped) {}
}
