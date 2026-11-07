package com.myaaptha.config;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import com.myaaptha.platform.media.*;
@SpringBootTest @AutoConfigureMockMvc
class UploadLevelIntegrationTest {
 @Autowired com.fasterxml.jackson.databind.ObjectMapper json;
 @Autowired MockMvc mvc; @Autowired JdbcTemplate jdbc;
 @Autowired UploadPolicyService policies;@Autowired MediaAssetService assets;
 @org.springframework.test.context.bean.override.mockito.MockitoBean MediaObjectStorage storage;
 long lastUserId;
 String login(boolean isAdmin)throws Exception{
  String name="upload-"+java.util.UUID.randomUUID();
  var created=mvc.perform(post("/api/users").contentType("application/json").content(json.writeValueAsString(java.util.Map.of("username",name,"password","UploadTestSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(java.util.UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
  long id=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();
  lastUserId=id;
  if(isAdmin)jdbc.update("UPDATE users SET role='ADMIN' WHERE id=?",id);
  var result=mvc.perform(post("/api/auth/login").contentType("application/json").content(json.writeValueAsString(java.util.Map.of("identifier",name,"password","UploadTestSecret123")))).andExpect(status().isOk()).andReturn();
  return "Bearer "+json.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
 }

 @Test void memberCannotEditPolicyAndDefaultIsOneGb()throws Exception{
  String token=login(false);
  mvc.perform(get("/api/uploads/policy").header("Authorization",token)).andExpect(status().isOk()).andExpect(jsonPath("$.level.storageBytes").value(1073741824));
  mvc.perform(put("/api/admin/upload-levels").header("Authorization",token).contentType("application/json").content("{}")).andExpect(status().isForbidden());
 }
 @Test void quotaReductionPreservesFilesAndBlocksNewUploads()throws Exception{
  login(false);long user=lastUserId;
  policies.save(new UploadPolicyService.Level(5,"Test limited",10,10,30,true));policies.assign(user,5);
  var file=new MockMultipartFile("file","test.txt","text/plain","hello".getBytes());
  var stored=assets.store(user,"TEST",file,java.util.Set.of("text/plain"),25,"test/");
  assertThat(assets.usage(user)).isEqualTo(5);
  policies.save(new UploadPolicyService.Level(5,"Test limited",4,10,30,true));
  assets.assertAvailable(stored.key());
  assertThatThrownBy(()->assets.store(user,"TEST",file,java.util.Set.of("text/plain"),25,"test/")).isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
  assertThat(assets.usage(user)).isEqualTo(5);
  jdbc.update("UPDATE media_assets SET expires_at=? WHERE storage_key=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(10)),stored.key());
  assertThatThrownBy(()->assets.assertAvailable(stored.key())).isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
 }
 @Test void adminCanAssignExistingLevel()throws Exception{
  login(false);long user=lastUserId;String admin=login(true);
  mvc.perform(put("/api/admin/upload-levels/users/"+user).header("Authorization",admin).contentType("application/json").content("{\"levelId\":2}")).andExpect(status().isOk());
  assertThat(policies.policy(user).id()).isEqualTo(2);
 }
}
