package com.myaaptha.domain.project;

import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

import com.myaaptha.domain.project.dto.CreateProjectRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
class ProjectControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private ObjectMapper objectMapper;

  @Test
  void shouldCreateAndListProjects() throws Exception {
    String accessToken = issueAccessToken();

    CreateProjectRequest request = new CreateProjectRequest();
    request.setName("Product Launch");
    request.setDescription("Launch the new AI experience");
    request.setStatus("Active");

    mockMvc.perform(post("/api/projects")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(request)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.name").value("Product Launch"))
      .andExpect(jsonPath("$.status").value("Active"));

    mockMvc.perform(get("/api/projects")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));
  }

  private String issueAccessToken() throws Exception {
    createUser("project-test-user", "project-test@myaaptha.ai", "secret123");

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"email\":\"project-test@myaaptha.ai\",\"password\":\"secret123\"}"))
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
