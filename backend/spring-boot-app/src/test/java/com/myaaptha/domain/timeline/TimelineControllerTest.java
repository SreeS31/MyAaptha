package com.myaaptha.domain.timeline;
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
@SpringBootTest @AutoConfigureMockMvc class TimelineControllerTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json;
 String member() throws Exception {String name="timeline-"+UUID.randomUUID();mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","ExampleSecret123","phoneNumber","+1779"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk());var result=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","ExampleSecret123")))).andExpect(status().isOk()).andReturn();return "Bearer "+json.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();}
 @Test void removalIsOwnerScopedIdempotentAndDoesNotChangeProfile() throws Exception {
  String owner=member(),other=member();String path="/api/timeline/events/profile-birth";
  String before=mvc.perform(get("/api/profile/me").header("Authorization",owner)).andReturn().getResponse().getContentAsString();
  String payload="{\"date\":\"2026-10-17\",\"kind\":\"Birth\",\"title\":\"Custom birth label\",\"detail\":\"Timeline only\"}";
  mvc.perform(put(path).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk());
  mvc.perform(delete(path)).andExpect(status().isUnauthorized());
  mvc.perform(delete(path).header("Authorization",other)).andExpect(status().isNoContent());
  mvc.perform(get("/api/timeline/events").header("Authorization",owner)).andExpect(jsonPath("$.length()").value(1));
  mvc.perform(put(path).header("Authorization",other).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk());
  mvc.perform(delete(path).header("Authorization",owner)).andExpect(status().isNoContent());
  mvc.perform(delete(path).header("Authorization",owner)).andExpect(status().isNoContent());
  mvc.perform(get("/api/timeline/events").header("Authorization",owner)).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(get("/api/timeline/events").header("Authorization",other)).andExpect(jsonPath("$.length()").value(1));
  mvc.perform(get("/api/profile/me").header("Authorization",owner)).andExpect(content().json(before));
  mvc.perform(delete("/api/timeline/events/bad.key").header("Authorization",owner)).andExpect(status().isBadRequest());
 }
 @Test void ownerScopedEventsPersistAndValidate() throws Exception {
  String owner=member(),other=member();String path="/api/timeline/events/custom-test";
  mvc.perform(put(path).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content("{\"date\":\"2026-10-08\",\"kind\":\"Employment\",\"title\":\"New role\",\"detail\":\"Started today\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/timeline/events").header("Authorization",owner)).andExpect(status().isOk()).andExpect(jsonPath("$[0].title").value("New role"));
  mvc.perform(get("/api/timeline/events").header("Authorization",other)).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(put(path).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content("{\"date\":\"invalid\",\"kind\":\"Employment\",\"title\":\"Bad date\"}")).andExpect(status().isBadRequest());
  mvc.perform(put(path).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content("{\"date\":\"2026-10-09\",\"kind\":\"Other\",\"title\":\"Updated role\"}")).andExpect(status().isOk());
  mvc.perform(get("/api/timeline/events").header("Authorization",owner)).andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].title").value("Updated role"));
 }
}
