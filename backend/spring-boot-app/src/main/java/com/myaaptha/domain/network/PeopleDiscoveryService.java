package com.myaaptha.domain.network;

import com.myaaptha.domain.ai.AiPreferenceService;
import com.myaaptha.domain.network.dto.NetworkPersonDto;
import com.myaaptha.domain.privacy.UserBlockRepository;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.settings.AppSettingsService;
import com.myaaptha.domain.settings.AppSettingsService.Settings;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.util.*;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

/** Build explanations only from the viewer's records and explicitly shared public signals. */
@Service
public class PeopleDiscoveryService {
  private final UserRepository users;private final UserProfileRepository profiles;
  private final RelationshipRepository relationships;private final UserBlockRepository blocks;
  private final AppSettingsService settings;private final AiPreferenceService aiPreferences;private final RestClient ai;
  public PeopleDiscoveryService(UserRepository users,UserProfileRepository profiles,RelationshipRepository relationships,
      UserBlockRepository blocks,AppSettingsService settings,AiPreferenceService aiPreferences,
      @Value("${myaaptha.ai.base-url:http://localhost:8081/api/v1}") String origin) {
    this.users=users;this.profiles=profiles;this.relationships=relationships;this.blocks=blocks;this.settings=settings;this.aiPreferences=aiPreferences;
    var factory=new JdkClientHttpRequestFactory(java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofMillis(800)).build());
    factory.setReadTimeout(Duration.ofMillis(800));ai=RestClient.builder().baseUrl(origin).requestFactory(factory).build();
  }
  public record Connection(Long userId,String displayName,String yourRelationship,String sharedRelationship) {}
  public record Match(NetworkPersonDto person,boolean alreadyConnected,String relationship,List<Connection> mutualConnections,
      List<String> sharedInterests,String sharedEmployer,List<String> reasons,int relevance) {}
  public record Result(List<Match> people,String rankingMode,boolean limited,String explanation) {}
  @com.fasterxml.jackson.annotation.JsonIgnoreProperties(ignoreUnknown=true)
  private record Rank(String id,double score) {}

  public Result search(Long viewer,String query) {
    String q=query==null?"":query.strip().toLowerCase(Locale.ROOT);
    if(q.length()<2||q.length()>160)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter between 2 and 160 characters");
    var hidden=new HashSet<Long>();
    blocks.findByBlockerUserIdOrBlockedUserId(viewer,viewer).forEach(b -> hidden.add(b.getBlockerUserId().equals(viewer)?b.getBlockedUserId():b.getBlockerUserId()));
    String pattern="%"+q.replace("!","!!").replace("%","!%").replace("_","!_")+"%";
    var candidates=users.discoverPeople(viewer,pattern,PageRequest.of(0,200)).stream().filter(u -> !hidden.contains(u.getId())).toList();
    if(candidates.isEmpty())return new Result(List.of(),"STANDARD",false,"Only discoverable people and your existing contacts are searched.");
    var targetIds=candidates.stream().map(UserEntity::getId).toList();
    var own=new LinkedHashMap<Long,RelationshipEntity>();
    relationships.findByOwnerUserId(viewer,PageRequest.of(0,500)).stream().filter(r -> r.getRelatedUserId()!=null&&!hidden.contains(r.getRelatedUserId())).forEach(r -> own.put(r.getRelatedUserId(),r));
    relationships.findByOwnerUserIdAndRelatedUserIdIn(viewer,targetIds).forEach(r -> own.put(r.getRelatedUserId(),r));
    var ids=new HashSet<Long>(targetIds);ids.addAll(own.keySet());ids.add(viewer);
    var prefs=settings.getAll(ids);var mine=prefs.getOrDefault(viewer,Settings.defaults());
    var profileMap=new HashMap<Long,UserProfileEntity>();profiles.findAllById(ids).forEach(p -> profileMap.put(p.getUserId(),p));
    var names=new HashMap<Long,String>();users.findAllById(own.keySet()).forEach(u -> names.put(u.getId(),name(u)));
    var pairBlocks=new HashSet<String>();blocks.findByBlockerUserIdInAndBlockedUserIdIn(ids,ids).forEach(b -> {pairBlocks.add(b.getBlockerUserId()+":"+b.getBlockedUserId());pairBlocks.add(b.getBlockedUserId()+":"+b.getBlockerUserId());});
    var edges=own.isEmpty()?List.<RelationshipEntity>of():relationships.publicConnections(own.keySet(),targetIds,PageRequest.of(0,1000));
    var results=new ArrayList<Match>();
    for(var user:candidates) {
      var their=prefs.getOrDefault(user.getId(),Settings.defaults());var profile=profileMap.get(user.getId());var known=own.get(user.getId());
      if(!their.discoverable()&&known==null)continue;
      var mutual=new LinkedHashMap<Long,Connection>();
      if(mine.shareConnections()&&their.shareConnections())for(var edge:edges) {
        Long other=user.getId().equals(edge.getOwnerUserId())?edge.getRelatedUserId():user.getId().equals(edge.getRelatedUserId())?edge.getOwnerUserId():null;
        if(other==null||other.equals(user.getId())||!own.containsKey(other)||hidden.contains(other)||pairBlocks.contains(other+":"+user.getId()))continue;
        if(edge.getRelativeToUserId()!=null&&!edge.getRelativeToUserId().equals(edge.getOwnerUserId()))continue;
        if(own.get(other).getRelativeToUserId()!=null&&!own.get(other).getRelativeToUserId().equals(viewer))continue;
        if(!prefs.getOrDefault(other,Settings.defaults()).shareConnections())continue;
        mutual.putIfAbsent(other,new Connection(other,names.getOrDefault(other,"MyAaptha member"),own.get(other).getType(),edge.getType()));
      }
      var common=new ArrayList<String>();String employer=null;
      var me=profileMap.get(viewer);
      if(mine.shareInterests()&&their.shareInterests()&&me!=null&&profile!=null) {
        var theirInterests=interests(profile.getHobbies());
        interests(me.getHobbies()).stream().filter(theirInterests::contains).limit(12).forEach(common::add);
        if(me.getEmployer()!=null&&!me.getEmployer().isBlank()&&me.getEmployer().strip().equalsIgnoreCase(profile.getEmployer()))employer=me.getEmployer().strip();
      }
      var reasons=new ArrayList<String>();if(known!=null)reasons.add("Already in your network: "+known.getType());
      if(!mutual.isEmpty())reasons.add(mutual.size()+" shared connection"+(mutual.size()==1?"":"s"));
      if(!common.isEmpty())reasons.add("Shared interests: "+String.join(", ",common));
      if(employer!=null)reasons.add("Same workplace: "+employer);
      if(reasons.isEmpty())reasons.add("No shared connection information available");
      int relevance=(known==null?0:30)+Math.min(30,mutual.size()*10)+Math.min(20,common.size()*5)+(employer==null?0:10);
      var person=new NetworkPersonDto(user.getId(),user.getFirstName(),user.getSurname(),name(user),null,user.getLocation(),user.getAccountStatus(),profile==null?null:profile.getProfilePhoto(),user.getIdentityType(),user.getManagedCategory(),user.getClaimStatus(),profile==null?null:profile.getGender());
      results.add(new Match(person,known!=null,known==null?null:known.getType(),List.copyOf(mutual.values()).stream().limit(10).toList(),common,employer,reasons,relevance));
    }
    String mode="STANDARD";var scores=new HashMap<Long,Double>();
    if(mine.intelligentSearch()&&aiPreferences.get(viewer).aiEnabled()) {
      try {
        // Send public names only. Relationship graphs, contact details and private profiles stay in this service.
        var payload=results.stream().map(m -> Map.of("id",m.person().id().toString(),"name",m.person().displayName())).toList();
        var ranked=ai.post().uri("/search/rank").body(Map.of("query",q,"candidates",payload)).retrieve().body(Rank[].class);
        if(ranked!=null){for(var rank:ranked)if(Double.isFinite(rank.score())&&rank.score()>=0&&rank.score()<=1)scores.put(Long.valueOf(rank.id()),rank.score());mode="AI_ASSISTED";}
      } catch(Exception unavailable){mode="LOCAL_FALLBACK";}
    }
    if(mine.intelligentSearch())results.sort(Comparator.<Match>comparingDouble(m -> m.relevance()+scores.getOrDefault(m.person().id(),0.0)*20).reversed().thenComparing(m -> m.person().displayName(),String.CASE_INSENSITIVE_ORDER));
    return new Result(results.stream().limit(50).toList(),mode,candidates.size()>=200||own.size()>=500||edges.size()>=1000||results.size()>50,
        "Suggestions explain shared information, not personal compatibility. Private relationships and hidden interests are not revealed.");
  }
  private static String name(UserEntity user){String value=((user.getFirstName()==null?"":user.getFirstName())+" "+(user.getSurname()==null?"":user.getSurname())).strip();return value.isEmpty()?user.getUsername():value;}
  private static Set<String> interests(String value){if(value==null)return Set.of();var set=new LinkedHashSet<String>();Arrays.stream(value.split("[,;|\\n]")).map(String::strip).map(s -> s.toLowerCase(Locale.ROOT)).filter(s -> !s.isEmpty()&&s.length()<=80).limit(40).forEach(set::add);return set;}
}
