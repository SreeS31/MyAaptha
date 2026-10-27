package com.myaaptha.platform.security;

import static org.assertj.core.api.Assertions.*;
import com.myaaptha.domain.network.PeopleDiscoveryService;
import com.myaaptha.domain.settings.AppSettingsService;
import com.myaaptha.domain.settings.AppSettingsService.Settings;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.privacy.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@Transactional
class DiscoveryPrivacyTest {
  @Autowired PeopleDiscoveryService discovery;
  @Autowired AppSettingsService settings;
  @Autowired UserRepository users;
  @Autowired UserProfileRepository profiles;
  @Autowired RelationshipRepository relationships;
  @Autowired UserBlockRepository blocks;
  UserEntity member(String name) {
    var u=new UserEntity();u.setUsername("discovery_"+java.util.UUID.randomUUID());u.setPasswordHash("unused");u.setFirstName(name);
    return users.saveAndFlush(u);
  }
  Settings sharing(boolean discoverable,boolean connections,boolean interests) {
    return new Settings(discoverable,connections,interests,false,false,false,false,"22:00","07:00","UTC",false);
  }
  void edge(UserEntity from,UserEntity to,String visibility) {
    var r=new RelationshipEntity();r.setOwnerUserId(from.getId());r.setRelatedUserId(to.getId());r.setType("Friend");r.setVisibilityScope(visibility);relationships.saveAndFlush(r);
  }
  void profile(UserEntity user) {
    var p=new UserProfileEntity();p.setUserId(user.getId());p.setHobbies("Reading, Hiking");p.setEmployer("Shared workplace");profiles.saveAndFlush(p);
  }
  @Test void undiscoverablePeopleAndBlockedPeopleAreExcluded() {
    var viewer=member("Viewer");var target=member("UniqueCandidate");
    settings.update(viewer.getId(),sharing(false,false,false));
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people()).isEmpty();
    settings.update(target.getId(),sharing(true,false,false));
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people()).hasSize(1);
    var block=new UserBlockEntity();block.setBlockerUserId(target.getId());block.setBlockedUserId(viewer.getId());blocks.saveAndFlush(block);
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people()).isEmpty();
  }
  @Test void sharedFactsRequireConsentAndPublicEdgesAndExcludePairBlocks() {
    var viewer=member("Viewer");var target=member("UniqueCandidate");var common=member("Common");
    for(var u:java.util.List.of(viewer,target,common))settings.update(u.getId(),sharing(true,true,true));
    profile(viewer);profile(target);edge(viewer,common,"FRIENDS");edge(target,common,"FRIENDS");
    var result=discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst();
    assertThat(result.mutualConnections()).isEmpty();assertThat(result.sharedInterests()).containsExactly("reading","hiking");
    assertThat(result.sharedEmployer()).isEqualTo("Shared workplace");assertThat(result.person().phoneNumber()).isNull();
    edge(common,target,"PUBLIC");
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst().mutualConnections()).hasSize(1);
    settings.update(common.getId(),sharing(true,false,true));
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst().mutualConnections()).isEmpty();
    settings.update(common.getId(),sharing(true,true,true));
    var block=new UserBlockEntity();block.setBlockerUserId(common.getId());block.setBlockedUserId(target.getId());blocks.saveAndFlush(block);
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst().mutualConnections()).isEmpty();
    settings.update(target.getId(),sharing(true,true,false));
    result=discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst();
    assertThat(result.sharedInterests()).isEmpty();assertThat(result.sharedEmployer()).isNull();
    assertThat(discovery.search(viewer.getId(),"Hiking").people()).isEmpty();
  }
  @Test void wildcardInputCannotEnumeratePeopleAndExistingContactsRemainAvailable() {
    var viewer=member("Viewer");var target=member("UniqueCandidate");settings.update(viewer.getId(),sharing(false,false,false));
    edge(viewer,target,"FRIENDS");
    assertThat(discovery.search(viewer.getId(),"UniqueCandidate").people().getFirst().alreadyConnected()).isTrue();
    assertThat(discovery.search(viewer.getId(),"%_").people()).isEmpty();
    assertThatThrownBy(()->discovery.search(viewer.getId(),"a")).isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
  }
}
