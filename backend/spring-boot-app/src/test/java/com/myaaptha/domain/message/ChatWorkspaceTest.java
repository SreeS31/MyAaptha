package com.myaaptha.domain.message;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:chat-workspace-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1"}) @AutoConfigureMockMvc
class ChatWorkspaceTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate db;@Autowired ChatRetentionService retention;
 record Member(long id,String bearer){}
 String body(Object o)throws Exception{return json.writeValueAsString(o);}
 Member member()throws Exception{String name="options-"+UUID.randomUUID();var r=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("username",name,"password","OptionTest123!","phoneNumber","+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();long id=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("identifier",name,"password","OptionTest123!")))).andExpect(status().isOk()).andReturn();return new Member(id,"Bearer "+json.readTree(login.getResponse().getContentAsString()).path("accessToken").asText());}
 long circle(Member a,Member b)throws Exception{mvc.perform(post("/api/network/relationships").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("relatedUserId",b.id,"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());var r=mvc.perform(post("/api/network/chats/groups").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Options circle","memberIds",List.of(b.id))))).andExpect(status().isOk()).andReturn();return json.readTree(r.getResponse().getContentAsString()).path("id").asLong();}
 String path(long c){return "/api/network/chats/workspace/CIRCLE/"+c;}
 @Test void optionsSyncWithoutLeakingToOtherMembersAndEnforceAdminTimers()throws Exception{
  var a=member();var b=member();var outsider=member();long c=circle(a,b);
  mvc.perform(put(path(c)).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("favourite",true,"theme","OCEAN","listName","College","muteSeconds",28800,"disappearingSeconds",86400)))).andExpect(status().isOk()).andExpect(jsonPath("$.favourite").value(true));
  mvc.perform(get(path(c)).header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.theme").value("OCEAN")).andExpect(jsonPath("$.listName").value("College"));
  mvc.perform(get(path(c)).header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.favourite").value(false)).andExpect(jsonPath("$.disappearingSeconds").value(86400));
  mvc.perform(put(path(c)).header("Authorization",b.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("disappearingSeconds",0)))).andExpect(status().isForbidden());
  mvc.perform(get(path(c)).header("Authorization",outsider.bearer)).andExpect(status().isForbidden());
  mvc.perform(put(path(c)).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("theme","INVALID")))).andExpect(status().isBadRequest());
  assertTrue(retention.muted(a.id,"CIRCLE",c));assertFalse(retention.muted(b.id,"CIRCLE",c));
 }
 @Test void clearAndExportAffectOnlyTheCurrentUserAndTimerExpiresNewContent()throws Exception{
  var a=member();var b=member();long c=circle(a,b);mvc.perform(put(path(c)).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("disappearingSeconds",86400)))).andExpect(status().isOk());
  var sent=mvc.perform(post("/api/network/circles/"+c+"/posts").header("Authorization",a.bearer).contentType(MediaType.MULTIPART_FORM_DATA).param("message","Timer message")).andExpect(status().isOk()).andReturn();long message=json.readTree(sent.getResponse().getContentAsString()).path("id").asLong();
  mvc.perform(get(path(c)+"/export").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
  mvc.perform(delete(path(c)+"/history").header("Authorization",b.bearer)).andExpect(status().isOk());
  mvc.perform(get(path(c)+"/export").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(get(path(c)+"/export").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
  db.update("UPDATE chat_message_expiry SET expires_at=? WHERE kind='CIRCLE' AND message_id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(2)),message);retention.expire();
  assertEquals("",db.queryForObject("SELECT message FROM circle_posts WHERE id=?",String.class,message));
  mvc.perform(get(path(c)+"/export").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
 }
 @Test void creatorMustTransferToAnAdminAndExitedMembersLoseAccess()throws Exception{
  var a=member();var b=member();long c=circle(a,b);
  mvc.perform(post(path(c)+"/exit").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isConflict());
  mvc.perform(post("/api/network/circles/"+c+"/admins/"+b.id).header("Authorization",a.bearer)).andExpect(status().isOk());
  mvc.perform(post(path(c)+"/exit").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("successorId",b.id)))).andExpect(status().isOk());
  mvc.perform(get(path(c)).header("Authorization",a.bearer)).andExpect(status().isForbidden());
  mvc.perform(get(path(c)).header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.creator").value(true));
 }
 @Test void directTimersAreSharedAndPersonalClearDoesNotEraseTheOtherCopy()throws Exception{
  var a=member();var b=member();var outsider=member();circle(a,b);String path="/api/network/chats/workspace/DIRECT/"+b.id;
  mvc.perform(put(path).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("disappearingSeconds",86400,"muteSeconds",0)))).andExpect(status().isOk());
  mvc.perform(put(path).header("Authorization",outsider.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("disappearingSeconds",86400)))).andExpect(status().isForbidden());
  var sent=mvc.perform(multipart("/api/network/messages/with/"+b.id).header("Authorization",a.bearer).param("message","Direct timer message")).andExpect(status().isOk()).andReturn();long id=json.readTree(sent.getResponse().getContentAsString()).path("id").asLong();
  mvc.perform(get("/api/network/chats/workspace/DIRECT/"+a.id).header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.disappearingSeconds").value(86400));
  mvc.perform(delete(path+"/history").header("Authorization",a.bearer)).andExpect(status().isOk());
  mvc.perform(get(path+"/export").header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(get("/api/network/chats/workspace/DIRECT/"+a.id+"/export").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
  db.update("UPDATE chat_message_expiry SET expires_at=? WHERE kind='DIRECT' AND message_id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(2)),id);retention.expire();assertEquals("",db.queryForObject("SELECT message FROM direct_messages WHERE id=?",String.class,id));
 }
 @Test void soleCreatorMustExplicitlyConfirmCircleRemoval()throws Exception{
  var a=member();var r=mvc.perform(post("/api/network/chats/groups").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Solo circle","memberIds",List.of())))).andExpect(status().isOk()).andReturn();long c=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();
  mvc.perform(get(path(c)).header("Authorization",a.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.solo").value(true));
  mvc.perform(post(path(c)+"/exit").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isConflict());
  mvc.perform(post(path(c)+"/exit").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("deleteEmptyCircle",true)))).andExpect(status().isOk());assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM circles WHERE id=?",Integer.class,c));
 }
}
