package com.myaaptha.domain.message;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest @AutoConfigureMockMvc
class UnifiedChatTest {
  @Autowired MockMvc mvc;
  @Autowired ObjectMapper json;
  @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
  record Member(long id,String token) {}
  Member member() throws Exception {
    String name="delete-"+UUID.randomUUID();
    var result=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","ExampleSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
    long id=json.readTree(result.getResponse().getContentAsString()).get("id").asLong();
    result=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","ExampleSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(id,"Bearer "+json.readTree(result.getResponse().getContentAsString()).get("accessToken").asText());
  }
  void connect(Member a,Member b) throws Exception {mvc.perform(post("/api/network/relationships").header("Authorization",a.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("relatedUserId",b.id(),"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());}
  long send(Member a,String path,String text) throws Exception {return json.readTree(mvc.perform(multipart(path).header("Authorization",a.token()).param("message",text)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();}


  long circle(Member owner,Member other) throws Exception {
    long id=json.readTree(mvc.perform(post("/api/network/circles").header("Authorization",owner.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("name","Forward "+UUID.randomUUID(),"description","Synthetic test")))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();
    if(other!=null)mvc.perform(post("/api/network/circles/"+id+"/members").header("Authorization",owner.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("userId",other.id())))).andExpect(status().isOk());
    return id;
  }
  Map<String,Object> target(String type,long id){return Map.of("type",type,"id",id);}
  org.springframework.test.web.servlet.ResultActions forward(Member user,String type,long conversation,long message,List<Map<String,Object>> targets) throws Exception {
    return mvc.perform(post("/api/network/chats/forward").header("Authorization",user.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("sourceType",type,"conversationId",conversation,"messageId",message,"targets",targets))));
  }
  @Test void mixedForwardLimitCopiesAttachmentsAndCirclePreviewsDoNotRead() throws Exception {
    var author=member();var receiver=member();connect(author,receiver);
    byte[] bytes="Shared attachment".getBytes(java.nio.charset.StandardCharsets.UTF_8);
    long source=json.readTree(mvc.perform(multipart("/api/network/messages/with/"+receiver.id()).file(new org.springframework.mock.web.MockMultipartFile("file","notes.txt","text/plain",bytes)).header("Authorization",author.token()).param("message","Forwarded content")).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();
    var targets=new ArrayList<Map<String,Object>>();targets.add(target("DIRECT",receiver.id()));
    var groups=new ArrayList<Long>();for(int i=0;i<9;i++){long id=circle(author,receiver);groups.add(id);targets.add(target("CIRCLE",id));}
    var eleven=new ArrayList<>(targets);eleven.add(target("CIRCLE",circle(author,null)));
    forward(author,"DIRECT",receiver.id(),source,eleven).andExpect(status().isBadRequest());
    forward(author,"DIRECT",receiver.id(),source,List.of()).andExpect(status().isBadRequest());
    forward(author,"DIRECT",receiver.id(),source,List.of(targets.get(0),targets.get(0))).andExpect(status().isBadRequest());
    forward(author,"DIRECT",receiver.id(),source,targets).andExpect(status().isOk()).andExpect(jsonPath("$.sent").value(10));
    long group=groups.get(0);
    for(int i=0;i<2;i++)mvc.perform(get("/api/network/chats/circles").header("Authorization",receiver.token())).andExpect(status().isOk()).andExpect(jsonPath("$[?(@.circleId == "+group+")].unreadCount").value(org.hamcrest.Matchers.contains(1)));
    var response=mvc.perform(get("/api/network/circles/"+group+"/posts").header("Authorization",author.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0].forwarded").value(true)).andReturn();
    long groupMessage=json.readTree(response.getResponse().getContentAsString()).get(0).get("id").asLong();
    mvc.perform(put("/api/network/chats/circles/"+group+"/"+groupMessage+"/flags").header("Authorization",author.token()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":true,\"pinned\":true}")).andExpect(status().isOk()).andExpect(jsonPath("$.starred").value(true));
    forward(author,"CIRCLE",group,groupMessage,List.of(target("DIRECT",receiver.id()))).andExpect(status().isOk());
    mvc.perform(delete("/api/network/messages/with/"+receiver.id()+"/"+source).header("Authorization",author.token())).andExpect(status().isOk());
    mvc.perform(get("/api/network/circles/"+group+"/posts/"+groupMessage+"/attachment").header("Authorization",receiver.token())).andExpect(status().isOk()).andExpect(content().bytes(bytes));
    mvc.perform(get("/api/network/circles/"+group+"/posts").header("Authorization",receiver.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0].starred").value(false)).andExpect(jsonPath("$[0].pinned").value(false));
    mvc.perform(delete("/api/network/circles/"+group+"/posts/"+groupMessage+"/for-me").header("Authorization",author.token())).andExpect(status().isNoContent());
    forward(author,"CIRCLE",group,groupMessage,List.of(target("DIRECT",receiver.id()))).andExpect(status().isNotFound());
  }
  @Test void oneForbiddenTargetRejectsWholeBatchAndSourcesRequireMembership() throws Exception {
    var owner=member();var sender=member();var stranger=member();connect(owner,sender);connect(sender,owner);
    long restricted=circle(owner,sender);jdbc.update("UPDATE circles SET posting_permission='ADMINS_ONLY' WHERE id=?",restricted);
    long source=send(sender,"/api/network/messages/with/"+owner.id(),"Do not partially forward");
    forward(sender,"DIRECT",owner.id(),source,List.of(target("DIRECT",owner.id()),target("CIRCLE",restricted))).andExpect(status().isForbidden());
    mvc.perform(get("/api/network/messages/with/"+sender.id()).header("Authorization",owner.token())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
    long groupSource=send(owner,"/api/network/circles/"+restricted+"/posts","Members only");
    long strangersCircle=circle(stranger,null);
    forward(stranger,"CIRCLE",restricted,groupSource,List.of(target("CIRCLE",strangersCircle))).andExpect(status().isForbidden());
    mvc.perform(get("/api/network/chats/circles").header("Authorization",stranger.token())).andExpect(status().isOk()).andExpect(jsonPath("$[?(@.circleId == "+restricted+")]").isEmpty());
    forward(sender,"DIRECT",owner.id(),source,List.of(target("DIRECT",stranger.id()))).andExpect(status().isForbidden());
  }
}
