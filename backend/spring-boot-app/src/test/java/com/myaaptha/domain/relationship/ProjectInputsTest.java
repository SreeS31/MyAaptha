package com.myaaptha.domain.relationship;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
@SpringBootTest @AutoConfigureMockMvc class ProjectInputsTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate db;
 String account(boolean admin)throws Exception {
  String name="inputs-"+UUID.randomUUID();String body=json.writeValueAsString(Map.of("username",name,"password","InputsSecret12345","phoneNumber","+1774"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L))));
  mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
  if(admin)db.update("UPDATE users SET role='ADMIN' WHERE username=?",name);
  var response=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","InputsSecret12345")))).andExpect(status().isOk()).andReturn();return "Bearer "+json.readTree(response.getResponse().getContentAsString()).get("accessToken").asText();
 }
 @Test void administratorOnlyVersionedDraftsRejectSecretsAndUnknownFields()throws Exception {
  String user=account(false),admin=account(true);
  mvc.perform(get("/api/admin/project-inputs").header("Authorization",user)).andExpect(status().isForbidden());
  mvc.perform(post("/api/admin/project-inputs/meta").header("Authorization",user).contentType(MediaType.APPLICATION_JSON).content("{\"values\":{},\"version\":0}")).andExpect(status().isForbidden());
  var initial=mvc.perform(get("/api/admin/project-inputs").header("Authorization",admin)).andExpect(status().isOk()).andReturn();assertThat(json.readTree(initial.getResponse().getContentAsString()).size()).isEqualTo(6);
  db.update("DELETE FROM project_input_tasks WHERE task_key='meta'");
  for(var values:List.of(Map.of("credentials","actual-secret-value"),Map.of("unexpected","value"),Map.of("appId","secret-not-id")))mvc.perform(post("/api/admin/project-inputs/meta").header("Authorization",admin).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("values",values,"version",0)))).andExpect(status().isBadRequest());
  var values=Map.of("status","App created","appId","1234567890","accountType","Creator","credentials","projects/test-project/secrets/meta/versions/latest");
  var body=json.writeValueAsString(Map.of("values",values,"version",0,"ready",true));
  mvc.perform(post("/api/admin/project-inputs/meta").header("Authorization",admin).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.ready").value(true)).andExpect(jsonPath("$.version").value(1)).andExpect(jsonPath("$.values.appId").value("1234567890"));
  mvc.perform(post("/api/admin/project-inputs/meta").header("Authorization",admin).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isConflict());
  mvc.perform(post("/api/admin/project-inputs/apns").header("Authorization",admin).contentType(MediaType.APPLICATION_JSON).content("{\"values\":{},\"ready\":true,\"version\":0}")).andExpect(status().isBadRequest());
  db.update("DELETE FROM project_input_tasks WHERE task_key='meta'");
 }
}
