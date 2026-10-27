package com.myaaptha.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.containsString;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties={"management.endpoints.web.exposure.include=health,info,prometheus",
    "management.endpoint.health.probes.enabled=true","management.endpoint.health.show-details=never",
    "management.health.redis.enabled=false","management.prometheus.metrics.export.enabled=true",
    "security.admin-mfa.required=false","security.metrics.scrape-token=synthetic-metrics-fixture-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"})
@AutoConfigureMockMvc
@AutoConfigureObservability(metrics=true,tracing=false)
class OperationalEndpointAccessTest {
  static final String SCRAPE="synthetic-metrics-fixture-"+"a".repeat(48);
  @Autowired MockMvc mvc;
  @Autowired ObjectMapper json;
  @Autowired JdbcTemplate jdbc;

  @Test void anonymousHealthProbesStayAvailableButMetricsAreProtected() throws Exception {
    for(String path:List.of("/actuator/health","/actuator/health/liveness","/actuator/health/readiness"))
      mvc.perform(get(path).header("Authorization","Bearer invalid-probe-token"))
          .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"))
          .andExpect(jsonPath("$.components").doesNotExist());
    mvc.perform(get("/actuator/prometheus")).andExpect(status().isUnauthorized());
    mvc.perform(get("/actuator/info")).andExpect(status().isUnauthorized());
  }
  @Test void memberCannotReadOperationalMetadataAndStillUsesOwnAccountApi() throws Exception {
    String token=account(false);
    for(String path:List.of("/actuator/prometheus","/actuator/info","/actuator"))
      mvc.perform(get(path).header("Authorization","Bearer "+token)).andExpect(status().isForbidden());
    mvc.perform(get("/api/auth/me").header("Authorization","Bearer "+token)).andExpect(status().isOk());
  }
  @Test void isolatedAdministratorFixtureCanReadMetricsAndInfo() throws Exception {
    String token=account(true);
    mvc.perform(get("/actuator/prometheus").header("Authorization","Bearer "+token))
        .andExpect(status().isOk()).andExpect(content().string(containsString("# HELP ")));
    mvc.perform(get("/actuator/info").header("Authorization","Bearer "+token)).andExpect(status().isOk());
  }
  @Test void machineCredentialCannotBeReusedForAccountOrAdministrationAccess() throws Exception {
    mvc.perform(get("/actuator/prometheus").header("Authorization","Bearer "+SCRAPE))
        .andExpect(status().isOk()).andExpect(content().string(containsString("# HELP ")));
    for(String path:List.of("/actuator/info","/api/auth/me","/api/admin/security/incidents"))
      mvc.perform(get(path).header("Authorization","Bearer "+SCRAPE)).andExpect(status().isUnauthorized());
    mvc.perform(get("/actuator/prometheus").header("Authorization","Bearer invalid"))
        .andExpect(status().isUnauthorized());
  }
  private String account(boolean administrator) throws Exception {
    String username="metrics-fixture-"+UUID.randomUUID(),password="Fixture-"+UUID.randomUUID();
    mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(
        Map.of("username",username,"phoneNumber","+1999"+String.valueOf(System.nanoTime()).substring(0,10),"password",password))))
        .andExpect(status().isOk());
    // Only the fresh synthetic row in this isolated H2 test database is promoted.
    if(administrator) jdbc.update("UPDATE users SET role='ADMIN' WHERE username=?",username);
    var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
        .content(json.writeValueAsString(Map.of("identifier",username,"password",password))))
        .andExpect(status().isOk()).andReturn();
    return json.readTree(login.getResponse().getContentAsString()).get("accessToken").asText();
  }
}
