package com.myaaptha.domain.social;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.*;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:community-social-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1"}) @AutoConfigureMockMvc
class CommunitySocialFeaturesTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate db;
 record Member(long id,String bearer){}
 String body(Object value)throws Exception{return json.writeValueAsString(value);}
 Member member()throws Exception{String name="social77-"+UUID.randomUUID();var r=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("username",name,"password","SocialTest123!","phoneNumber","+1775"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();long id=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("identifier",name,"password","SocialTest123!")))).andExpect(status().isOk()).andReturn();return new Member(id,"Bearer "+json.readTree(login.getResponse().getContentAsString()).path("accessToken").asText());}
 void connect(Member a,Member b)throws Exception{mvc.perform(post("/api/network/relationships").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("relatedUserId",b.id,"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());}
 long circle(Member a,Member b)throws Exception{connect(a,b);var r=mvc.perform(post("/api/network/chats/groups").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Community test","memberIds",List.of(b.id))))).andExpect(status().isOk()).andReturn();return json.readTree(r.getResponse().getContentAsString()).path("id").asLong();}
 String activities(long c){return "/api/network/circles/"+c+"/activities";}
 JsonNode create(Member a,String path,Object value)throws Exception{return json.readTree(mvc.perform(post(path).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(value))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());}
 @Test void pollsRequireMembershipAndValidateEveryOptionAndClosePermission()throws Exception{
  var a=member();var b=member();var outsider=member();long c=circle(a,b);String path=activities(c);
  var poll=create(a,path,Map.of("kind","POLL","title","Ride day?","options",List.of("Saturday","Sunday")));long id=poll.path("id").asLong(),option=poll.path("options").get(0).path("id").asLong(),second=poll.path("options").get(1).path("id").asLong();
  mvc.perform(get(path).header("Authorization",outsider.bearer)).andExpect(status().isForbidden());
  mvc.perform(post(path+"/"+id+"/vote").header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("optionIds",List.of(option,second))))).andExpect(status().isBadRequest());
  mvc.perform(post(path+"/"+id+"/vote").header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("optionIds",List.of(Long.MAX_VALUE))))).andExpect(status().isBadRequest());
  create(b,path+"/"+id+"/vote",Map.of("optionIds",List.of(option)));create(b,path+"/"+id+"/vote",Map.of("optionIds",List.of(second)));assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM community_poll_votes WHERE activity_id=?",Integer.class,id));
  mvc.perform(post(path+"/"+id+"/close").header("Authorization",b.bearer)).andExpect(status().isForbidden());create(a,path+"/"+id+"/close",Map.of());
  mvc.perform(post(path+"/"+id+"/vote").header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("optionIds",List.of(option))))).andExpect(status().isConflict());
  mvc.perform(delete("/api/network/circles/"+c+"/members/"+b.id).header("Authorization",a.bearer)).andExpect(status().isOk());mvc.perform(get(path).header("Authorization",b.bearer)).andExpect(status().isForbidden());
 }
 @Test void eventsKeepOneRsvpAndRejectInvalidTimesAndAdminOnlyCreation()throws Exception{
  var a=member();var b=member();long c=circle(a,b);String path=activities(c);var event=create(a,path,Map.of("kind","EVENT","title","Meetup","startsAt",Instant.now().plusSeconds(3600).toString(),"location","Club house"));long id=event.path("id").asLong();
  create(b,path+"/"+id+"/rsvp",Map.of("response","YES"));create(b,path+"/"+id+"/rsvp",Map.of("response","MAYBE"));assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM community_event_rsvps WHERE activity_id=?",Integer.class,id));
  mvc.perform(post(path).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("kind","EVENT","title","Past","startsAt",Instant.now().minusSeconds(60).toString())))).andExpect(status().isBadRequest());
  mvc.perform(post(path).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("kind","EVENT","title","Invalid end","startsAt",Instant.now().plusSeconds(7200).toString(),"endsAt",Instant.now().plusSeconds(3600).toString())))).andExpect(status().isBadRequest());
  mvc.perform(post(path+"/"+id+"/rsvp").header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("response","INVALID")))).andExpect(status().isBadRequest());
  db.update("UPDATE circles SET posting_permission='ADMINS_ONLY' WHERE id=?",c);mvc.perform(post(path).header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("kind","POLL","title","No permission","options",List.of("A","B"))))).andExpect(status().isForbidden());
 }
 @Test void closeFriendStatusArchiveAndHighlightsNeverExpandAudience()throws Exception{
  var a=member();var b=member();var other=member();connect(a,b);connect(a,other);create(a,"/api/social/tools/close-friends/"+b.id,Map.of());
  var r=mvc.perform(multipart("/api/social/stories").header("Authorization",a.bearer).param("caption","Private text status").param("audience","CLOSE_FRIENDS").param("archive","true").param("archive","true")).andExpect(status().isOk()).andExpect(jsonPath("$.mediaUrl").isEmpty()).andReturn();long id=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();
  create(b,"/api/social/stories/"+id+"/view",Map.of());create(b,"/api/social/tools/stories/"+id+"/reaction",Map.of("emoji","\uD83D\uDC4D"));mvc.perform(post("/api/social/stories/"+id+"/view").header("Authorization",other.bearer)).andExpect(status().isForbidden());
  mvc.perform(get("/api/social/tools/stories/"+id+"/viewers").header("Authorization",b.bearer)).andExpect(status().isForbidden());mvc.perform(get("/api/social/tools/stories/"+id+"/viewers").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
  db.update("UPDATE social_stories SET expires_at=? WHERE id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(3600)),id);mvc.perform(post("/api/social/stories/"+id+"/view").header("Authorization",b.bearer)).andExpect(status().isForbidden());mvc.perform(get("/api/social/tools/archive").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
  create(a,"/api/social/tools/stories/"+id+"/highlight",Map.of("name","Friends"));create(b,"/api/social/stories/"+id+"/view",Map.of());mvc.perform(delete("/api/social/tools/close-friends/"+b.id).header("Authorization",a.bearer)).andExpect(status().isOk());mvc.perform(post("/api/social/stories/"+id+"/view").header("Authorization",b.bearer)).andExpect(status().isForbidden());
 }
 @Test void collectionsKeepOldSavesAndReelsExcludePrivateDiaryVideos()throws Exception{
  var a=member();var b=member();var r=mvc.perform(multipart("/api/social/posts").header("Authorization",a.bearer).param("caption","An older saved post").param("audience","PUBLIC")).andExpect(status().isOk()).andReturn();long id=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();
  create(b,"/api/social/tools/collections/"+id,Map.of("name","Learning"));create(b,"/api/social/tools/collections/"+id,Map.of("name","Books"));create(b,"/api/social/tools/collections/"+id,Map.of("name","Books"));assertEquals(2,db.queryForObject("SELECT COUNT(*) FROM social_saved_collections WHERE user_id=? AND post_id=?",Integer.class,b.id,id));
  for(int i=0;i<105;i++)db.update("INSERT INTO social_posts(author_user_id,caption,audience) VALUES(?,?,'PUBLIC')",a.id,"Later post "+i);
  mvc.perform(get("/api/social/saved").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(id));
  db.update("INSERT INTO social_posts(author_user_id,caption,audience,media_type) VALUES(?,'Shared reel','PUBLIC','video/mp4')",a.id);db.update("INSERT INTO social_posts(author_user_id,caption,audience,media_type) VALUES(?,'Private video','PRIVATE','video/mp4')",a.id);
  var page=json.readTree(mvc.perform(get("/api/social/browse?mode=REELS").header("Authorization",a.bearer)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());assertTrue(page.path("items").toString().contains("Shared reel"));assertFalse(page.path("items").toString().contains("Private video"));
  db.update("UPDATE social_posts SET audience='PRIVATE' WHERE id=?",id);mvc.perform(get("/api/social/tools/collections/posts?name=Learning").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(0));
 }
 @Test void privateArchiveRequiresExplicitChoiceAndDoesNotResurrectExpiredStatus()throws Exception{
  var a=member();var first=mvc.perform(multipart("/api/social/stories").header("Authorization",a.bearer).param("caption","Normal status")).andExpect(status().isOk()).andReturn();long normal=json.readTree(first.getResponse().getContentAsString()).path("id").asLong();
  var kept=mvc.perform(multipart("/api/social/stories").header("Authorization",a.bearer).param("caption","Keep my archive").param("archive","true")).andExpect(status().isOk()).andReturn();long archived=json.readTree(kept.getResponse().getContentAsString()).path("id").asLong();
  mvc.perform(get("/api/social/tools/archive").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].id").value(archived));
  db.update("UPDATE social_stories SET expires_at=? WHERE author_user_id=?",java.sql.Timestamp.from(Instant.now().minusSeconds(60)),a.id);
  mvc.perform(get("/api/social/tools/stories/"+normal+"/reactions").header("Authorization",a.bearer)).andExpect(status().isForbidden());mvc.perform(get("/api/social/tools/stories/"+archived+"/reactions").header("Authorization",a.bearer)).andExpect(status().isOk());assertNull(db.queryForObject("SELECT archive_until FROM social_stories WHERE id=?",java.sql.Timestamp.class,normal));
 }
 @Test void reelsUploadRejectsNonVideoWithoutPublishingAPost()throws Exception{
  var a=member();mvc.perform(multipart("/api/social/reels").header("Authorization",a.bearer).param("caption","Not a reel").param("audience","PUBLIC").file(new org.springframework.mock.web.MockMultipartFile("file","note.txt","text/plain","Plain text".getBytes(java.nio.charset.StandardCharsets.UTF_8)))).andExpect(status().isBadRequest());assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM social_posts WHERE author_user_id=?",Integer.class,a.id));
 }
}
