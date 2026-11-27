package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.when;

import com.myaaptha.domain.ai.ContactOrganizerController.AcceptedContactSuggestion;
import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.NetworkCircleDto;
import com.myaaptha.domain.network.dto.NetworkPersonDto;
import com.myaaptha.domain.network.dto.NetworkRelationshipDto;
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
  void shouldKeepConfirmedSingleContactWithoutCreatingAnAutomaticCircle() {
    var person = new NetworkPersonDto(99L, "Email", "Contact", "Email Contact", null, null,
        "MANAGED", null, "MANAGED", "OTHER", "GUARDIAN_APPROVAL_REQUIRED", null);
    var relationship = new NetworkRelationshipDto(7L, "Friend", "FRIENDS", null,
        "email@example.com", null, null, null, null, null, person);
    when(network.addPerson(eq(1L), any())).thenReturn(relationship);
    when(circles.findByOwnerUserId(1L)).thenReturn(List.of());

    var result = new ContactOrganizerService(network, circles).accept(1L, List.of(
        new AcceptedContactSuggestion("Email Contact", null, "email@example.com",
            "Friend", List.of("Friends"), true)));

    assertEquals(1, result.peopleAdded());
    assertEquals(0, result.circleMembershipsAdded());
    verify(network,never()).createCircle(any(),any());
    verify(network,never()).addCircleMember(any(),any(),any());
  }
 @Test void threeDistinctConfirmedPeopleAreRequiredForNewSuggestedCircles(){
  var relationships=new java.util.ArrayList<NetworkRelationshipDto>();
  for(long id:List.of(99L,100L,101L)){var person=new NetworkPersonDto(id,"Person","","Person "+id,null,null,"ACTIVE",null,"ACCOUNT",null,null,null);relationships.add(new NetworkRelationshipDto(id,"Friend","FRIENDS",null,null,null,null,null,null,null,person));}
  when(network.addPerson(eq(1L),any())).thenReturn(relationships.get(0),relationships.get(1),relationships.get(2));when(circles.findByOwnerUserId(1L)).thenReturn(List.of());
  when(network.createCircle(eq(1L),any())).thenReturn(new NetworkCircleDto(5L,"Friends","Suggested",List.of(),"Owner",null,true,true,"MEMBERS",true));
  var result=new ContactOrganizerService(network,circles).accept(1L,List.of(new AcceptedContactSuggestion("A",null,"a@example.test","Friend",List.of("Friends"),true),new AcceptedContactSuggestion("B",null,"b@example.test","Friend",List.of("friends"),true),new AcceptedContactSuggestion("C",null,"c@example.test","Friend",List.of("Friends"),true)));
  assertEquals(3,result.circleMembershipsAdded());verify(network).createCircle(eq(1L),any());for(long id:List.of(99L,100L,101L))verify(network).addCircleMember(1L,5L,id);
 }

}
