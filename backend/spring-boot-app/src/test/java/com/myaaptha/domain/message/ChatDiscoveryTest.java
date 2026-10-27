package com.myaaptha.domain.message;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest @AutoConfigureMockMvc
class ChatDiscoveryTest {
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

  @Test void groupCreationIsAtomicAndSearchRespectsMembershipAndHiddenMessages() throws Exception {
    var owner=member();var friend=member();var outsider=member();connect(owner,friend);
    long before=jdbc.queryForObject("SELECT count(*) FROM circles",Long.class);
    mvc.perform(post("/api/network/chats/groups").header("Authorization",owner.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("name","Invalid group","memberIds",List.of(friend.id(),outsider.id()))))).andExpect(status().isBadRequest());
    org.assertj.core.api.Assertions.assertThat(jdbc.queryForObject("SELECT count(*) FROM circles",Long.class)).isEqualTo(before);
    var created=mvc.perform(post("/api/network/chats/groups").header("Authorization",owner.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("name","Our group","memberIds",List.of(friend.id()))))).andExpect(status().isOk()).andReturn();
    long circle=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();
    String path="/api/network/circles/"+circle+"/posts";long groupMessage=send(owner,path,"discoveryneedle group");
    long direct=send(owner,"/api/network/messages/with/"+friend.id(),"discoveryneedle direct");
    mvc.perform(get("/api/network/chats/search?q=discoveryneedle").header("Authorization",friend.token())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(2));
    mvc.perform(get("/api/network/chats/search?q=discoveryneedle").header("Authorization",outsider.token())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
    mvc.perform(delete(path+"/"+groupMessage+"/for-me").header("Authorization",friend.token())).andExpect(status().isNoContent());
    mvc.perform(delete("/api/network/messages/with/"+owner.id()+"/"+direct+"/for-me").header("Authorization",friend.token())).andExpect(status().isNoContent());
    mvc.perform(get("/api/network/chats/search?q=discoveryneedle").header("Authorization",friend.token())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
    mvc.perform(get("/api/network/chats/search?q=discoveryneedle").header("Authorization",owner.token())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(2));
  }
}
