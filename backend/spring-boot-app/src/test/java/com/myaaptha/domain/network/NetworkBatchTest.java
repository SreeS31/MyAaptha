package com.myaaptha.domain.network;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;

class NetworkBatchTest {
  @Test void largeNetworksUseBoundedBatchesAndPreserveTheOwnerContract() {
    var users = mock(UserRepository.class); var relations = mock(RelationshipRepository.class); var profiles = mock(UserProfileRepository.class);
    var service = new NetworkService(users, relations, mock(com.myaaptha.domain.circle.CircleRepository.class),
        mock(org.springframework.security.crypto.password.PasswordEncoder.class), profiles,
        mock(com.myaaptha.domain.notification.NotificationService.class), mock(com.myaaptha.domain.privacy.UserBlockRepository.class));
    var records = new ArrayList<RelationshipEntity>(); var people = new HashMap<Long, UserEntity>(); var profileMap = new HashMap<Long, UserProfileEntity>();
    for (long id = 1; id <= 501; id++) {
      var person = new UserEntity(); ReflectionTestUtils.setField(person, "id", id); person.setFirstName("Person " + id); people.put(id, person);
      var profile = new UserProfileEntity(); profile.setUserId(id); profile.setGender("FEMALE"); profileMap.put(id, profile);
      var relation = new RelationshipEntity(); relation.setOwnerUserId(900L); relation.setRelatedUserId(id); relation.setType("Friend"); relation.setContactPhone("private"); records.add(relation);
    }
    when(relations.findByOwnerUserId(900L)).thenReturn(records);
    when(users.findAllById(any())).thenAnswer(call -> { List<Long> ids = call.getArgument(0); assertTrue(ids.size() <= 500); return ids.stream().map(people::get).toList(); });
    when(profiles.findAllById(any())).thenAnswer(call -> { List<Long> ids = call.getArgument(0); return ids.stream().map(profileMap::get).toList(); });
    var result = service.relationships(900L);
    assertEquals(501, result.size()); assertEquals("FEMALE", result.getLast().person().gender()); assertEquals("private", result.getLast().contactPhone());
    verify(users, times(2)).findAllById(any()); verify(profiles, times(2)).findAllById(any());
    verify(users, never()).findById(any()); verify(profiles, never()).findById(any());
    verify(relations).findByOwnerUserId(900L);
  }
  @Test void circlesBatchSharedMembersAndKeepOwnerSpecificNamesAndPermissions() {
    var users=mock(UserRepository.class);var relations=mock(RelationshipRepository.class);var profiles=mock(UserProfileRepository.class);
    var circles=mock(com.myaaptha.domain.circle.CircleRepository.class);
    var service=new NetworkService(users,relations,circles,mock(org.springframework.security.crypto.password.PasswordEncoder.class),profiles,
        mock(com.myaaptha.domain.notification.NotificationService.class),mock(com.myaaptha.domain.privacy.UserBlockRepository.class));
    var people=new HashMap<Long,UserEntity>();
    for(long id=1;id<=501;id++){var u=new UserEntity();ReflectionTestUtils.setField(u,"id",id);u.setFirstName("Person "+id);people.put(id,u);}
    var first=new com.myaaptha.domain.circle.model.CircleEntity();first.setOwnerUserId(1L);first.setName("First");first.getMemberUserIds().addAll(people.keySet());first.getAdminUserIds().add(1L);
    var second=new com.myaaptha.domain.circle.model.CircleEntity();second.setOwnerUserId(2L);second.setName("Second");second.getMemberUserIds().addAll(people.keySet());second.setPostingPermission("ADMINS_ONLY");second.getAdminUserIds().add(2L);
    when(circles.findVisibleToUser(1L)).thenReturn(List.of(first,second));
    when(users.findAllById(any())).thenAnswer(call->{List<Long> ids=call.getArgument(0);assertTrue(ids.size()<=500);return ids.stream().map(people::get).toList();});
    when(relations.findByOwnerUserIdInAndRelatedUserIdIn(any(),any())).thenAnswer(call->{Collection<Long> ids=call.getArgument(1);if(!ids.contains(3L))return List.of();var r=new RelationshipEntity();r.setOwnerUserId(1L);r.setRelatedUserId(3L);r.setContactName("Owner's label");return List.of(r);});
    var result=service.circles(1L);
    assertEquals(501,result.getFirst().members().size());assertTrue(result.getFirst().currentUserAdmin());assertFalse(result.getLast().currentUserCanPost());
    assertEquals("Owner's label",result.getFirst().members().stream().filter(m->m.person().id()==3L).findFirst().orElseThrow().person().displayName());
    assertEquals("Person 3",result.getLast().members().stream().filter(m->m.person().id()==3L).findFirst().orElseThrow().person().displayName());
    verify(users,times(2)).findAllById(any());verify(profiles,times(2)).findAllById(any());verify(users,never()).findById(any());verify(profiles,never()).findById(any());
  }
}
