package com.myaaptha.domain;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.Locale;

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
import com.myaaptha.domain.task.dto.CreateTaskRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
class DataQualityConstraintIntegrationTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private ObjectMapper objectMapper;

  private String cachedAccessToken;

  @Test
  void shouldRejectProjectWithInvalidStatusViaDbConstraint() {
    CreateProjectRequest request = new CreateProjectRequest();
    request.setName("Constraint Test Project");
    request.setDescription("Project should fail with invalid status");
    request.setStatus("Archived");

    assertConstraintViolationOnCreate("/api/projects", request, "chk_projects_status_allowed");
  }

  @Test
  void shouldRejectTaskWithBlankTitleViaDbConstraint() {
    CreateTaskRequest request = new CreateTaskRequest();
    request.setTitle("   ");
    request.setDetails("Task should fail because title is blank after trim");
    request.setStatus("Todo");

    assertConstraintViolationOnCreate("/api/tasks", request, "chk_tasks_title_not_blank");
  }

  @Test
  void shouldRejectMilestoneWithInvalidStatusViaDbConstraint() {
    CreateMilestoneRequest request = new CreateMilestoneRequest();
    request.setName("Constraint Test Milestone");
    request.setDescription("Milestone should fail with invalid status");
    request.setStatus("Paused");

    assertConstraintViolationOnCreate("/api/milestones", request, "chk_milestones_status_allowed");
  }

  private void assertConstraintViolationOnCreate(String endpoint, Object payload, String constraintName) {
    Exception exception = assertThrows(Exception.class, () -> mockMvc.perform(post(endpoint)
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + issueAccessToken())
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(payload)))
      .andReturn());

    String fullMessage = collectMessages(exception).toLowerCase(Locale.ROOT);
    assertTrue(
      fullMessage.contains(constraintName.toLowerCase(Locale.ROOT)),
      () -> "Expected constraint name '" + constraintName + "' in exception chain, but got: " + fullMessage
    );
  }

  private String collectMessages(Throwable throwable) {
    StringBuilder builder = new StringBuilder();
    Throwable current = throwable;
    while (current != null) {
      if (current.getMessage() != null) {
        builder.append(current.getMessage()).append('\n');
      }
      current = current.getCause();
    }
    return builder.toString();
  }

  private String issueAccessToken() throws Exception {
    if (cachedAccessToken != null) {
      return cachedAccessToken;
    }

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"email\":\"admin@myaaptha.ai\",\"password\":\"admin123\"}"))
      .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isOk())
      .andReturn();

    cachedAccessToken = objectMapper.readTree(loginResult.getResponse().getContentAsString()).get("accessToken").asText();
    return cachedAccessToken;
  }
}
