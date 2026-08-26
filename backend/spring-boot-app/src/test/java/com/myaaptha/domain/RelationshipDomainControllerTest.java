package com.myaaptha.domain;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
class RelationshipDomainControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private ObjectMapper objectMapper;

  @Test
  void shouldManagePeople() throws Exception {
    assertCrudLifecycle("/api/people", "{\"fullName\":\"Alex Morgan\",\"email\":\"alex@myaaptha.ai\"}",
        "{\"fullName\":\"Alex Taylor\",\"email\":\"alex.taylor@myaaptha.ai\"}", "fullName", "Alex Taylor");
  }

  @Test
  void shouldManageCircles() throws Exception {
    assertCrudLifecycle("/api/circles", "{\"name\":\"Product Guild\",\"description\":\"Product collaboration circle\"}",
        "{\"name\":\"Platform Guild\",\"description\":\"Platform collaboration circle\"}", "name", "Platform Guild");
  }

  @Test
  void shouldManageRelationships() throws Exception {
    assertCrudLifecycle("/api/relationships", "{\"type\":\"Collaborates with\"}",
        "{\"type\":\"Reports to\"}", "type", "Reports to");
  }

  @Test
  void shouldManagePermissions() throws Exception {
    assertCrudLifecycle("/api/permissions", "{\"name\":\"workspace.read\",\"description\":\"Read workspace information\"}",
        "{\"name\":\"workspace.write\",\"description\":\"Write workspace information\"}", "name", "workspace.write");
  }

  private void assertCrudLifecycle(String endpoint, String createPayload, String updatePayload, String field, String updatedValue)
      throws Exception {
    String accessToken = issueAccessToken();

    MvcResult createResult = mockMvc.perform(post(endpoint)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(createPayload))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id", notNullValue()))
      .andReturn();

    long id = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

    mockMvc.perform(get(endpoint)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));

    mockMvc.perform(put(endpoint + "/{id}", id)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(updatePayload))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$." + field).value(updatedValue));

    mockMvc.perform(get(endpoint + "/{id}", id)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$." + field).value(updatedValue));

    mockMvc.perform(delete(endpoint + "/{id}", id)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isNoContent());

    mockMvc.perform(get(endpoint + "/{id}", id)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isNotFound());
  }

  private String issueAccessToken() throws Exception {
    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"email\":\"admin@myaaptha.ai\",\"password\":\"admin123\"}"))
      .andExpect(status().isOk())
      .andReturn();

    return objectMapper.readTree(loginResult.getResponse().getContentAsString()).get("accessToken").asText();
  }
}
