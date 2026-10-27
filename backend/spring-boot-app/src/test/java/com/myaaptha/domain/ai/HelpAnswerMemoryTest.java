package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:help-memory;MODE=PostgreSQL;DB_CLOSE_DELAY=-1","security.fields.enabled=true","security.fields.active-key-id=test","security.fields.keys=test=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="})
@AutoConfigureMockMvc
class HelpAnswerMemoryTest {
  @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate jdbc;
  @Autowired HelpAnswerMemory memory;
  @MockitoBean HelpChatProvider provider;
  record Member(long id,String bearer){}
  Member member(boolean admin)throws Exception{
    String name="help-"+UUID.randomUUID();
    var created=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","HelpTestSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
    long id=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();
    if(admin)jdbc.update("UPDATE users SET role='ADMIN' WHERE id=?",id);
    var auth=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","HelpTestSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(id,"Bearer "+json.readTree(auth.getResponse().getContentAsString()).get("accessToken").asText());
  }
  JsonNode ask(Member user,String question,List<?> history,String retry)throws Exception{
    var data=new HashMap<String,Object>();data.put("message",question);data.put("history",history);data.put("useAi",true);if(retry!=null)data.put("retryOf",retry);
    var response=mvc.perform(post("/api/ai/help/chat").header("Authorization",user.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(data))).andExpect(status().isOk()).andReturn();
    return json.readTree(response.getResponse().getContentAsString());
  }
  @BeforeEach void setup()throws Exception{
    jdbc.update("DELETE FROM help_exchanges");memory.clearShared();memory.enhancedEnabled(false);
    when(provider.configured()).thenReturn(true);when(provider.model()).thenReturn("gpt-4.1-mini");
    when(provider.answer(anyString(),anyList(),anyList())).thenReturn(new HelpChatProvider.Result("MyAaptha is free for all users.",List.of("pricing"),100,30));
    when(provider.answer(anyString(),anyList(),anyList(),eq("gpt-4.1"))).thenReturn(new HelpChatProvider.Result("MyAaptha is free. There is no subscription fee for users.",List.of("pricing"),110,40));
  }
  @Test void privateCacheIsContextScopedEncryptedAndAvoidsPaidCalls()throws Exception{
    var a=member(false);var b=member(false);
    var first=ask(a,"Is MyAaptha free?",List.of(),null);assertEquals("AI",first.get("mode").asText());
    assertEquals("CACHE",ask(a,"  IS MyAaptha  free? ",List.of(),null).get("mode").asText());
    verify(provider,times(1)).answer(anyString(),anyList(),anyList());
    assertEquals("AI",ask(b,"Is MyAaptha free?",List.of(),null).get("mode").asText());
    assertEquals("AI",ask(a,"Is MyAaptha free?",List.of(Map.of("role","user","content","My private account question")),null).get("mode").asText());
    verify(provider,times(3)).answer(anyString(),anyList(),anyList());
    assertEquals(4L,jdbc.queryForObject("SELECT COUNT(*) FROM help_exchanges",Long.class));
    assertTrue(jdbc.queryForObject("SELECT payload FROM help_exchanges WHERE id=?",String.class,first.get("exchangeId").asText()).startsWith("enc:v1:"));
    assertEquals(100,jdbc.queryForObject("SELECT input_tokens FROM help_exchanges WHERE id=?",Integer.class,first.get("exchangeId").asText()));
    assertNotEquals(memory.key("free",List.of(),"model-a"),memory.key("free",List.of(),"model-b"));
    assertNotEquals(memory.key("can I share",List.of(),"m"),memory.key("can't I share",List.of(),"m"));
  }
  @Test void onlyAdminCanEnableRetryAndOnlyOwnerCanRetryBaseAnswer()throws Exception{
    var a=member(false);var b=member(false);var admin=member(true);
    String id=ask(a,"Is MyAaptha free?",List.of(),null).get("exchangeId").asText();
    String retry=json.writeValueAsString(Map.of("message","retry","useAi",true,"retryOf",id));
    mvc.perform(post("/api/ai/help/chat").header("Authorization",a.bearer()).contentType(MediaType.APPLICATION_JSON).content(retry)).andExpect(status().isForbidden());
    mvc.perform(put("/api/ai/help/admin/settings").header("Authorization",a.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"enhancedEnabled\":true}")).andExpect(status().isForbidden());
    mvc.perform(put("/api/ai/help/admin/settings").header("Authorization",admin.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"enhancedEnabled\":true}")).andExpect(status().isOk());
    mvc.perform(post("/api/ai/help/chat").header("Authorization",b.bearer()).contentType(MediaType.APPLICATION_JSON).content(retry)).andExpect(status().isNotFound());
    var stronger=ask(a,"Ignored client override",List.of(),id);
    assertEquals("ENHANCED",stronger.get("tier").asText());assertEquals("gpt-4.1",stronger.get("model").asText());
    assertEquals("CACHE",ask(a,"retry",List.of(),id).get("mode").asText());
    verify(provider,times(1)).answer(eq("Is MyAaptha free?"),anyList(),anyList(),eq("gpt-4.1"));
    mvc.perform(post("/api/ai/help/chat").header("Authorization",a.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("message","retry","useAi",true,"retryOf",stronger.get("exchangeId").asText())))).andExpect(status().isBadRequest());
  }
  @Test void approvedPublicAnswerIsReusableAndCanBeInvalidated()throws Exception{
    var admin=member(true);var user=member(false);
    var value=json.writeValueAsString(Map.of("question","Is MyAaptha free?","answer","Free for all users.","sourceIds",List.of("pricing"),"confirmedPublic",true));
    mvc.perform(post("/api/ai/help/admin/answers").header("Authorization",user.bearer()).contentType(MediaType.APPLICATION_JSON).content(value)).andExpect(status().isForbidden());
    mvc.perform(post("/api/ai/help/admin/answers").header("Authorization",admin.bearer()).contentType(MediaType.APPLICATION_JSON).content(value)).andExpect(status().isOk());
    assertEquals("CACHE",ask(user,"Is MyAaptha free?",List.of(),null).get("mode").asText());
    verify(provider,never()).answer(anyString(),anyList(),anyList());
    memory.clearShared();memory.clear(user.id());
    assertEquals("AI",ask(user,"Is MyAaptha free?",List.of(),null).get("mode").asText());
    jdbc.update("UPDATE help_exchanges SET expires_at=TIMESTAMP '2000-01-01 00:00:00'");
    assertEquals("AI",ask(user,"Is MyAaptha free?",List.of(),null).get("mode").asText());
  }
  @Test void clearingAndDisablingRetentionDeletesOnlyOwnHistory()throws Exception{
    var a=member(false);var b=member(false);
    ask(a,"pricing",List.of(),null);ask(b,"pricing",List.of(),null);
    mvc.perform(delete("/api/ai/help/history").header("Authorization",a.bearer())).andExpect(status().isOk());
    assertEquals(0L,jdbc.queryForObject("SELECT COUNT(*) FROM help_exchanges WHERE user_id=?",Long.class,a.id()));
    assertEquals(1L,jdbc.queryForObject("SELECT COUNT(*) FROM help_exchanges WHERE user_id=?",Long.class,b.id()));
    mvc.perform(put("/api/ai/preferences").header("Authorization",b.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"aiEnabled\":true,\"allowSensitiveData\":false,\"allowPersonalization\":false,\"activityRetentionDays\":0}")).andExpect(status().isOk());
    var reply=ask(b,"pricing",List.of(),null);assertTrue(reply.get("exchangeId").isNull());
    assertEquals(0L,jdbc.queryForObject("SELECT COUNT(*) FROM help_exchanges",Long.class));
  }
}
