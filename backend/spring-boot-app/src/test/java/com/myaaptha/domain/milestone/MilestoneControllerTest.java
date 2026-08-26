package com.myaaptha.domain.milestone;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
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

import com.myaaptha.domain.milestone.dto.CreateMilestoneRequest;
import com.myaaptha.domain.project.dto.CreateProjectRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
class MilestoneControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private ObjectMapper objectMapper;

  @Test
  void shouldCreateListUpdateDeleteAndFilterMilestones() throws Exception {
    String accessToken = issueAccessToken();

    CreateProjectRequest projectRequest = new CreateProjectRequest();
    projectRequest.setName("Milestone Test Project");
    projectRequest.setDescription("Project used to validate milestone project linkage");
    projectRequest.setStatus("Active");

    MvcResult projectResult = mockMvc.perform(post("/api/projects")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(projectRequest)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id", notNullValue()))
      .andReturn();

    Long projectId = objectMapper.readTree(projectResult.getResponse().getContentAsString()).get("id").asLong();

    CreateMilestoneRequest request = new CreateMilestoneRequest();
    request.setName("Beta release candidate");
    request.setDescription("Ship beta candidate with dashboard and module APIs");
    request.setStatus("Planned");
    request.setProjectId(projectId);
    request.setDueDate(java.time.LocalDate.parse("2026-10-15"));

    MvcResult createResult = mockMvc.perform(post("/api/milestones")
      .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(request)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id", notNullValue()))
      .andExpect(jsonPath("$.name").value("Beta release candidate"))
      .andExpect(jsonPath("$.status").value("Planned"))
      .andExpect(jsonPath("$.dueDate").value("2026-10-15"))
      .andReturn();

    Long milestoneId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

    mockMvc.perform(get("/api/milestones")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));

    mockMvc.perform(get("/api/milestones")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .param("projectId", projectId.toString()))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));

    CreateMilestoneRequest updateRequest = new CreateMilestoneRequest();
    updateRequest.setName("Beta release updated");
    updateRequest.setDescription("Updated rollout milestone");
    updateRequest.setStatus("Blocked");
    updateRequest.setProjectId(projectId);
    updateRequest.setDueDate(java.time.LocalDate.parse("2026-11-01"));
    updateRequest.setBlockedReason("Waiting for security approval");

    mockMvc.perform(put("/api/milestones/{id}", milestoneId)
      .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(updateRequest)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.name").value("Beta release updated"))
      .andExpect(jsonPath("$.status").value("Blocked"))
      .andExpect(jsonPath("$.dueDate").value("2026-11-01"))
      .andExpect(jsonPath("$.blockedReason").value("Waiting for security approval"));

    mockMvc.perform(get("/api/milestones/{id}", milestoneId)
      .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id").value(milestoneId))
      .andExpect(jsonPath("$.dueDate").value("2026-11-01"))
      .andExpect(jsonPath("$.blockedReason").value("Waiting for security approval"));

    mockMvc.perform(post("/api/milestones/bulk-status")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"milestoneIds\":[" + milestoneId + "],\"status\":\"Blocked\"}"))
      .andExpect(status().isBadRequest());

    mockMvc.perform(post("/api/milestones/bulk-status")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"milestoneIds\":[" + milestoneId + "],\"status\":\"Blocked\",\"blockedReason\":\"Dependency from vendor API\"}"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$", hasSize(1)))
      .andExpect(jsonPath("$[0].status").value("Blocked"))
      .andExpect(jsonPath("$[0].blockedReason").value("Dependency from vendor API"));

    mockMvc.perform(post("/api/milestones/bulk-status")
      .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"milestoneIds\":[" + milestoneId + "],\"status\":\"Completed\"}"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$", hasSize(1)))
      .andExpect(jsonPath("$[0].status").value("Completed"))
      .andExpect(jsonPath("$[0].blockedReason", nullValue()));

    mockMvc.perform(delete("/api/milestones/{id}", milestoneId)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isNoContent());

    mockMvc.perform(get("/api/milestones/{id}", milestoneId)
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

  private void createUser(String username, String email, String password) throws Exception {
    mockMvc.perform(post("/api/users")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"username\":\"" + username + "\",\"email\":\"" + email + "\",\"phoneNumber\":\"+1555" + Math.abs(username.hashCode()) + "\",\"password\":\"" + password + "\"}"))
      .andExpect(status().isOk());
  }
}
