package com.myaaptha.config;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.myaaptha.platform.state.EphemeralState;
@SpringBootTest @AutoConfigureMockMvc @Import(UploadSecurityIntegrationTest.UploadController.class)
class UploadSecurityIntegrationTest {
 @Autowired com.fasterxml.jackson.databind.ObjectMapper json;
 @Autowired MockMvc mvc; @Autowired JdbcTemplate jdbc; @Autowired EphemeralState state;
 @RestController static class UploadController {
  @PostMapping("/api/test/security-upload") String upload(@RequestPart MultipartFile file){return "accepted";}
  @GetMapping("/api/test/security-error") String error(){throw new IllegalStateException("secret content must not leak");}
 }
 String member,admin;
 String login(boolean isAdmin)throws Exception{
  String name="upload-"+java.util.UUID.randomUUID();
  var created=mvc.perform(post("/api/users").contentType("application/json").content(json.writeValueAsString(java.util.Map.of("username",name,"password","UploadTestSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(java.util.UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
  long id=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();
  if(isAdmin)jdbc.update("UPDATE users SET role='ADMIN' WHERE id=?",id);
  var result=mvc.perform(post("/api/auth/login").contentType("application/json").content(json.writeValueAsString(java.util.Map.of("identifier",name,"password","UploadTestSecret123")))).andExpect(status().isOk()).andReturn();
  return "Bearer "+json.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
 }
 @BeforeEach void users()throws Exception{member=login(false);admin=login(true);}
 @BeforeEach void reset(){state.delete("security:block:198.51.100.44");state.delete("security:event:198.51.100.44:MALWARE");}
 @Test void malwareBypassingClientIsRejectedReportedAndBlocked()throws Exception{
  var file=new MockMultipartFile("file","test.txt","text/plain","EICAR-STANDARD-ANTIVIRUS-TEST-FILE".getBytes());
  mvc.perform(multipart("/api/test/security-upload").file(file).header("Authorization",member).with(r->{r.setRemoteAddr("198.51.100.44");return r;})).andExpect(status().isBadRequest());
  assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM security_incidents WHERE category='MALWARE' AND ip_address='198.51.100.44'",Long.class)).isPositive();
  mvc.perform(get("/api/profile/me").header("Authorization",member).with(r->{r.setRemoteAddr("198.51.100.44");return r;})).andExpect(status().isForbidden());
  mvc.perform(get("/api/admin/security").header("Authorization",member)).andExpect(status().isForbidden());
  mvc.perform(get("/api/admin/security").header("Authorization",admin)).andExpect(status().isOk()).andExpect(jsonPath("$.items").isArray());
 }
 @Test void ordinaryUnsupportedFileDoesNotBanAndTextWorks()throws Exception{
  mvc.perform(multipart("/api/test/security-upload").file(new MockMultipartFile("file","archive.zip","application/zip","unsupported".getBytes())).header("Authorization",member).with(r->{r.setRemoteAddr("198.51.100.45");return r;})).andExpect(status().isBadRequest());
  assertThat(state.get("security:block:198.51.100.45")).isNull();
  mvc.perform(multipart("/api/test/security-upload").file(new MockMultipartFile("file","notes.txt","application/octet-stream","ordinary text".getBytes())).header("Authorization",member).with(r->{r.setRemoteAddr("198.51.100.45");return r;})).andExpect(status().isOk());
 }
 @Test void serverErrorsAreRedactedAndReported()throws Exception{
  mvc.perform(get("/api/test/security-error").header("Authorization",member).with(r->{r.setRemoteAddr("198.51.100.46");return r;})).andExpect(status().isInternalServerError()).andExpect(jsonPath("$.message").value("An unexpected server error occurred. Please try again."));
  assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM security_incidents WHERE category='SERVER_ERROR'",Long.class)).isPositive();
 }
}
