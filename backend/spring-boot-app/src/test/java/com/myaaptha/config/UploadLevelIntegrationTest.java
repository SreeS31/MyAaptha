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
@SpringBootTest(properties="myaaptha.storage.retention-cleanup-cron=-") @AutoConfigureMockMvc
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
  mvc.perform(get("/api/uploads/policy").header("Authorization",token)).andExpect(status().isOk()).andExpect(jsonPath("$.level.storageBytes").value(1073741824)).andExpect(jsonPath("$.defaultRetentionDays").value(0)).andExpect(result->assertThat(json.convertValue(json.readTree(result.getResponse().getContentAsString()).get("retentionDaysOptions"),int[].class)).containsExactly(1,7,30,60,90,180,365,730,1095,1825,3650,0));
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
  assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,stored.key())).isNull();
  org.mockito.Mockito.verify(storage,org.mockito.Mockito.never()).delete(stored.key());
 }
 @Test void adminCanAssignExistingLevel()throws Exception{
  login(false);long user=lastUserId;String admin=login(true);
  mvc.perform(put("/api/admin/upload-levels/users/"+user).header("Authorization",admin).contentType("application/json").content("{\"levelId\":2}")).andExpect(status().isOk());
  assertThat(policies.policy(user).id()).isEqualTo(2);
 }
 @Test void paidQuotaCanReachOneHundredGbButCannotExceedIt(){
  var maximum=policies.save(new UploadPolicyService.Level(4,"Paid",107374182400L,26214400,36500,true));
  assertThat(maximum.storageBytes()).isEqualTo(107374182400L);
  assertThatThrownBy(()->policies.save(new UploadPolicyService.Level(4,"Too large",107374182401L,26214400,36500,true))).isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
 }
 @Test @org.springframework.transaction.annotation.Transactional
 void unreleasedMigrationsPreserveEveryExistingExpirySelection()throws Exception{
  login(false);long user=lastUserId;
  var file=new MockMultipartFile("file","test.txt","text/plain","hello".getBytes());
  var normal=assets.store(user,"TEST",file,java.util.Set.of("text/plain"),25,"migration/");
  var story=assets.store(user,"TEST",file,java.util.Set.of("text/plain"),25,"migration/");
  var deleted=assets.store(user,"TEST",file,java.util.Set.of("text/plain"),25,"migration/");
  var when=java.sql.Timestamp.from(java.time.Instant.now().plusSeconds(86400));
  for(var item:java.util.List.of(normal,story,deleted))jdbc.update("UPDATE media_assets SET expires_at=? WHERE storage_key=?",when,item.key());
  jdbc.update("UPDATE media_assets SET deleted_at=CURRENT_TIMESTAMP WHERE storage_key=?",deleted.key());
  jdbc.update("INSERT INTO social_stories(author_user_id,media_key,media_type,expires_at) VALUES(?,?,?,?)",user,story.key(),"text/plain",when);
  new org.springframework.jdbc.datasource.init.ResourceDatabasePopulator(new org.springframework.core.io.ClassPathResource("db/migration/common/V72__nonexpiring_active_files.sql")).execute(jdbc.getDataSource());
  new org.springframework.jdbc.datasource.init.ResourceDatabasePopulator(new org.springframework.core.io.ClassPathResource("db/migration/common/V73__user_selected_file_expiry.sql")).execute(jdbc.getDataSource());
  assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,normal.key())).isNotNull();
  for(var item:java.util.List.of(story,deleted))assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,item.key())).isNotNull();
  assets.assertAvailable(normal.key());
 }

 @Test void selectedExpiryDeniesDownloadsAndDeletesOnlyExpiredObjects()throws Exception{
  login(false);long user=lastUserId;
  var never=storeWithDays(user,"0");var future=storeWithDays(user,"3650");var expired=storeWithDays(user,"1");
  assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,never.key())).isNull();
  assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,future.key())).isNotNull();
  jdbc.update("UPDATE media_assets SET expires_at=? WHERE storage_key=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(5)),expired.key());
  assertThatThrownBy(()->assets.assertAvailable(expired.key())).isInstanceOfSatisfying(org.springframework.web.server.ResponseStatusException.class,error->assertThat(error.getStatusCode().value()).isEqualTo(410));
  assets.cleanupExpired();
  org.mockito.Mockito.verify(storage).delete(expired.key());
  org.mockito.Mockito.verify(storage,org.mockito.Mockito.never()).delete(never.key());
  org.mockito.Mockito.verify(storage,org.mockito.Mockito.never()).delete(future.key());
  assertThat(jdbc.queryForObject("SELECT deleted_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,expired.key())).isNotNull();
  assets.assertAvailable(never.key());assets.assertAvailable(future.key());
  assertThat(assets.usage(user)).isEqualTo(10);
 }
 private MediaAssetService.StoredAsset storeWithDays(long user,String days){
  var request=new org.springframework.mock.web.MockHttpServletRequest("POST","/api/files");request.setParameter("retentionDays",days);
  org.springframework.web.context.request.RequestContextHolder.setRequestAttributes(new org.springframework.web.context.request.ServletRequestAttributes(request));
  try{return assets.store(user,"TEST",new MockMultipartFile("file","test.txt","text/plain","hello".getBytes()),java.util.Set.of("text/plain"),25,"expiry/");}
  finally{org.springframework.web.context.request.RequestContextHolder.resetRequestAttributes();}
 }

}
