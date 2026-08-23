package com.circlenet.domain.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.circlenet.domain.ai.ContactOrganizerController.AcceptedContactSuggestion;
import com.circlenet.domain.circle.CircleRepository;
import com.circlenet.domain.network.NetworkService;
import com.circlenet.domain.network.dto.NetworkCircleDto;
import com.circlenet.domain.network.dto.NetworkPersonDto;
import com.circlenet.domain.network.dto.NetworkRelationshipDto;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ContactOrganizerServiceTest {
  @Mock NetworkService network;
  @Mock CircleRepository circles;

  @Test
  void shouldCreateConfirmedEmailRelationshipAndSuggestedCircleMembership() {
    var person = new NetworkPersonDto(99L, "Email", "Contact", "Email Contact", null, null,
        "MANAGED", null, "MANAGED", "OTHER", "GUARDIAN_APPROVAL_REQUIRED", null);
    var relationship = new NetworkRelationshipDto(7L, "Friend", "FRIENDS", null,
        "email@example.com", null, null, null, null, null, person);
    var circle = new NetworkCircleDto(5L, "Friends", "Suggested", List.of(),
        "Owner", null, true, true, "MEMBERS", true);
    when(network.addPerson(eq(1L), any())).thenReturn(relationship);
    when(circles.findByOwnerUserId(1L)).thenReturn(List.of());
    when(network.createCircle(eq(1L), any())).thenReturn(circle);

    var result = new ContactOrganizerService(network, circles).accept(1L, List.of(
        new AcceptedContactSuggestion("Email Contact", null, "email@example.com",
            "Friend", List.of("Friends"), true)));

    assertEquals(1, result.peopleAdded());
    assertEquals(1, result.circleMembershipsAdded());
    verify(network).addCircleMember(1L, 5L, 99L);
  }
}
