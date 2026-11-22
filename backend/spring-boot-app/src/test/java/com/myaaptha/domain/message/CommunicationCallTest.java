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

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:communication-call-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1"})
@AutoConfigureMockMvc
class CommunicationCallTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate db;
 @Autowired CommunicationCallService calls;
 record Member(long id,String bearer){}
 Member member()throws Exception{String name="call-"+UUID.randomUUID();var registered=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","CallTestSecret123!","phoneNumber","+1779"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","CallTestSecret123!")))).andExpect(status().isOk()).andReturn();return new Member(json.readTree(registered.getResponse().getContentAsString()).path("id").asLong(),"Bearer "+json.readTree(login.getResponse().getContentAsString()).path("accessToken").asText());}
 String body(Object value)throws Exception{return json.writeValueAsString(value);}
 long circle(Member owner,Member other)throws Exception{mvc.perform(post("/api/network/relationships").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("relatedUserId",other.id,"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());var created=mvc.perform(post("/api/network/circles").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Call circle","description","Synthetic")))).andExpect(status().isOk()).andReturn();long id=json.readTree(created.getResponse().getContentAsString()).path("id").asLong();mvc.perform(post("/api/network/circles/"+id+"/members").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("userId",other.id)))).andExpect(status().isOk());return id;}
 String start(Member owner,String scope,long target)throws Exception{return json.readTree(mvc.perform(post("/api/network/meetings").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("scope",scope,"targetId",target,"callType","VIDEO")))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).path("id").asText();}
 @Test void circleCallsAuthorizeEveryJoinAndSignalAndRespectEnd()throws Exception{
  var owner=member();var friend=member();var outsider=member();long circle=circle(owner,friend);String id=start(owner,"CIRCLE",circle);
  assertEquals(id,start(friend,"CIRCLE",circle));
  mvc.perform(get("/api/network/meetings").header("Authorization",friend.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(id));
  mvc.perform(get("/api/network/meetings/"+id).header("Authorization",outsider.bearer)).andExpect(status().isForbidden());
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",outsider.bearer)).andExpect(status().isForbidden());
  String signal=body(Map.of("recipientId",friend.id,"type","offer","payload",body(Map.of("type","offer","sdp","synthetic-sdp"))));
  mvc.perform(post("/api/network/meetings/"+id+"/signals").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(signal)).andExpect(status().isForbidden());
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",friend.bearer)).andExpect(status().isOk());
  mvc.perform(post("/api/network/meetings/"+id+"/signals").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("recipientId",friend.id,"type","offer","payload","not-json")))).andExpect(status().isBadRequest());
  mvc.perform(post("/api/network/meetings/"+id+"/signals").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("recipientId",outsider.id,"type","offer","payload",body(Map.of("type","offer","sdp","synthetic")))))).andExpect(status().isForbidden());
  mvc.perform(post("/api/network/meetings/"+id+"/signals").header("Authorization",owner.bearer).contentType(MediaType.APPLICATION_JSON).content(signal)).andExpect(status().isOk());
  mvc.perform(get("/api/network/meetings/"+id+"/signals").header("Authorization",owner.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(get("/api/network/meetings/"+id+"/signals").header("Authorization",friend.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$[0].senderId").value(owner.id));
  mvc.perform(post("/api/network/meetings/"+id+"/end").header("Authorization",friend.bearer)).andExpect(status().isForbidden());
  mvc.perform(post("/api/network/meetings/"+id+"/end").header("Authorization",owner.bearer)).andExpect(status().isOk());
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",friend.bearer)).andExpect(status().isConflict());
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM communication_call_signals WHERE call_id=?",Integer.class,id));
 }
 @Test void removedMembersCannotReadSignalsAndExpiredCallsDoNotRevive()throws Exception{
  var owner=member();var friend=member();long circle=circle(owner,friend);String id=start(owner,"CIRCLE",circle);
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",friend.bearer)).andExpect(status().isOk());
  mvc.perform(delete("/api/network/circles/"+circle+"/members/"+friend.id).header("Authorization",owner.bearer)).andExpect(status().isOk());
  mvc.perform(get("/api/network/meetings/"+id+"/signals").header("Authorization",friend.bearer)).andExpect(status().isForbidden());
  db.update("UPDATE communication_call_members SET last_seen=? WHERE call_id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(120)),id);
  mvc.perform(get("/api/network/meetings/"+id).header("Authorization",owner.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.ended").value(true));
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",owner.bearer)).andExpect(status().isConflict());
 }
 @Test void unconnectedAccountsAndInvalidModesCannotStartCalls()throws Exception{
  var a=member();var b=member();mvc.perform(post("/api/network/meetings").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("scope","DIRECT","targetId",b.id,"callType","AUDIO")))).andExpect(status().isForbidden());
  mvc.perform(post("/api/network/meetings").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("scope","DIRECT","targetId",b.id,"callType","BOGUS")))).andExpect(status().isBadRequest());
 }
 @Test void directAudioCallsCanBeAnsweredAndEndedByTheRecipient()throws Exception{
  var a=member();var b=member();circle(a,b);
  var result=mvc.perform(post("/api/network/meetings").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("scope","DIRECT","targetId",b.id,"callType","AUDIO")))).andExpect(status().isOk()).andExpect(jsonPath("$.callType").value("AUDIO")).andReturn();
  String id=json.readTree(result.getResponse().getContentAsString()).path("id").asText();
  mvc.perform(get("/api/network/meetings").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(id));
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.members.length()").value(2));
  mvc.perform(post("/api/network/meetings/"+id+"/end").header("Authorization",b.bearer)).andExpect(status().isOk());
  mvc.perform(get("/api/network/meetings/history").header("Authorization",b.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$[0].ended").value(true));
  assertNotEquals(id,start(b,"DIRECT",a.id));
 }
 @Test void eightParticipantCapacityIsEnforcedOnTheServer()throws Exception{
  var owner=member();var friend=member();long circle=circle(owner,friend);String id=start(owner,"CIRCLE",circle);
  mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",friend.bearer)).andExpect(status().isOk());
  for(int i=0;i<7;i++){var next=member();db.update("INSERT INTO circle_members(circle_id,user_id) VALUES (?,?)",circle,next.id);mvc.perform(post("/api/network/meetings/"+id+"/join").header("Authorization",next.bearer)).andExpect(i==6?status().isConflict():status().isOk());}
  mvc.perform(get("/api/network/meetings/"+id).header("Authorization",owner.bearer)).andExpect(status().isOk()).andExpect(jsonPath("$.members.length()").value(8));
 }
 @Test void abandonedSignalingAndOldCallHistoryAreRemoved()throws Exception{
  var owner=member();var friend=member();long circle=circle(owner,friend);String id=start(owner,"CIRCLE",circle);
  db.update("INSERT INTO communication_call_signals(call_id,sender_user_id,recipient_user_id,signal_type,payload,created_at) VALUES (?,?,?,'offer','synthetic',?)",id,owner.id,friend.id,java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(360)));
  calls.purgeExpiredSignaling();assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM communication_call_signals WHERE call_id=?",Integer.class,id));
  db.update("UPDATE communication_calls SET created_at=? WHERE id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(691200)),id);calls.purgeExpiredSignaling();
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM communication_calls WHERE id=?",Integer.class,id));
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=?",Integer.class,id));
 }
}
