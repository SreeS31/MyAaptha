package com.myaaptha.domain.message;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class RelationshipBroadcastServiceTest {
  @Mock RelationshipRepository relationships;
  @Mock UserRepository users;
  @Mock UserProfileRepository profiles;
  @Mock DirectMessageService directMessages;
  @Mock RelationshipBroadcastRepository broadcasts;
  RelationshipBroadcastService service;

  @BeforeEach void setup() {
    service = new RelationshipBroadcastService(relationships, users, profiles, directMessages, broadcasts);
    when(profiles.findById(org.mockito.ArgumentMatchers.anyLong())).thenReturn(Optional.empty());
    for (long id : List.of(10L, 11L, 12L, 13L, 14L)) {
      UserEntity value = user(id);
      when(users.findById(id)).thenReturn(Optional.of(value));
    }
    when(relationships.findByOwnerUserId(1L)).thenReturn(List.of(
        relation(10, "Father", null), relation(11, "Son", 10L), relation(12, "Daughter", 10L),
        relation(13, "Friend", null), relation(14, "Son", 11L)));
  }

  @Test void horizontalTargetsOnlyChildrenOfSelectedNode() {
    var preview = service.preview(1L, "HORIZONTAL", 10L, null);
    assertEquals(List.of(11L, 12L), preview.recipients().stream().map(item -> item.userId()).toList());
  }

  @Test void verticalTargetsAnchorAndEveryDescendant() {
    var preview = service.preview(1L, "VERTICAL", 10L, null);
    assertEquals(List.of(10L, 11L, 12L, 14L), preview.recipients().stream().map(item -> item.userId()).toList());
  }

  @Test void locationMatchesOnlyOwnedRelationships() {
    var preview = service.preview(1L, "LOCATION", null, "Hyderabad");
    assertEquals(5, preview.recipients().size());
  }

  @Test void depthSelectsAnExactGenerationOrABoundedBranch(){
    assertEquals(List.of(14L),service.preview(1L,"HORIZONTAL",10L,null,2).recipients().stream().map(x->x.userId()).toList());
    assertEquals(List.of(10L,11L,12L),service.preview(1L,"VERTICAL",10L,null,1).recipients().stream().map(x->x.userId()).toList());
    assertEquals(List.of(10L,11L,12L,14L),service.preview(1L,"VERTICAL",10L,null,2).recipients().stream().map(x->x.userId()).toList());
    assertEquals(List.of(),service.preview(1L,"HORIZONTAL",10L,null,3).recipients());
  }
  @Test void rejectsInvalidDepthAndAnchorsOutsideOwnedTree(){
    for(int depth:List.of(0,-1,11))org.junit.jupiter.api.Assertions.assertThrows(org.springframework.web.server.ResponseStatusException.class,()->service.preview(1L,"VERTICAL",10L,null,depth));
    org.junit.jupiter.api.Assertions.assertThrows(org.springframework.web.server.ResponseStatusException.class,()->service.preview(1L,"VERTICAL",999L,null,2));
  }
  @Test void cyclesAndDuplicateEdgesCannotCrossBackThroughSender(){
    when(relationships.findByOwnerUserId(1L)).thenReturn(List.of(relation(10,"Father",null),relation(11,"Son",10L),relation(11,"Son",10L),relation(10,"Son",11L),relation(1,"Son",11L),relation(13,"Friend",null)));
    assertEquals(List.of(10L,11L),service.preview(1L,"VERTICAL",10L,null,null).recipients().stream().map(x->x.userId()).toList());
  }
  @Test void sendingRespectsTheSameDepthAsPreview(){
    when(broadcasts.save(org.mockito.ArgumentMatchers.any())).thenAnswer(invocation->invocation.getArgument(0));
    var result=service.send(1L,"HORIZONTAL",10L,null,"Two levels",null,2);
    assertEquals(1,result.deliveredCount());
    org.mockito.Mockito.verify(directMessages).send(1L,14L,"Two levels",null);
    org.mockito.Mockito.verifyNoMoreInteractions(directMessages);
  }

  private RelationshipEntity relation(long userId, String type, Long anchor) {
    RelationshipEntity value = new RelationshipEntity(); value.setOwnerUserId(1L);
    value.setRelatedUserId(userId); value.setType(type); value.setRelativeToUserId(anchor); return value;
  }
  private UserEntity user(long id) {
    UserEntity value = org.mockito.Mockito.mock(UserEntity.class);
    when(value.getId()).thenReturn(id); when(value.getFirstName()).thenReturn("Person " + id);
    when(value.getAccountStatus()).thenReturn("ACTIVE"); when(value.getIdentityType()).thenReturn("ACCOUNT");
    when(value.getLocation()).thenReturn("Hyderabad"); return value;
  }
}
