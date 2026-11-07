package com.myaaptha.domain.auth;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.springframework.http.HttpHeaders;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Autowired
  private ObjectMapper objectMapper;

  @Autowired
  private AuthTokenRepository authTokenRepository;

  @Test
  void shouldRejectUnknownAndDuplicateJsonFieldsBeforeAuthentication() throws Exception {
    for (String payload : new String[] {
        "{\"identifier\":\"json-contract-fixture\",\"password\":\"synthetic-password\",\"unexpected\":true}",
        "{\"identifier\":\"json-contract-fixture\",\"identifier\":\"another-fixture\",\"password\":\"synthetic-password\"}"
    }) {
      mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(payload))
          .andExpect(status().isBadRequest());
    }
  }

  @Test
  void shouldLoginWithValidCredentials() throws Exception {
    createUser("auth-login-user", "auth-login@myaaptha.ai", "secret123");

    mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-login@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.tokenType").value("Bearer"))
      .andExpect(jsonPath("$.accessToken", not(nullValue())))
      .andExpect(jsonPath("$.refreshToken", not(nullValue())))
      .andExpect(jsonPath("$.expiresIn").value(900));
  }

  @Test
  void shouldRefreshTokens() throws Exception {
    createUser("auth-refresh-user", "auth-refresh@myaaptha.ai", "secret123");

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-refresh@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andReturn();

    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    mockMvc.perform(post("/api/auth/refresh")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(loginPayload.refreshToken))))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.tokenType").value("Bearer"))
      .andExpect(jsonPath("$.accessToken", not(nullValue())))
      .andExpect(jsonPath("$.refreshToken", not(nullValue())));
  }

  @Test
  void shouldStoreOnlyRefreshTokenFingerprint() throws Exception {
    createUser("auth-fingerprint-user", "auth-fingerprint@myaaptha.ai", "secret123");
    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-fingerprint@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk()).andReturn();
    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    org.junit.jupiter.api.Assertions.assertTrue(authTokenRepository.findAll().stream()
        .noneMatch(token -> loginPayload.refreshToken.equals(token.getToken())));
    org.junit.jupiter.api.Assertions.assertTrue(authTokenRepository.findAll().stream()
        .anyMatch(token -> token.getToken() != null && token.getToken().matches("[0-9a-f]{64}")));
  }

  @Test
  void shouldRejectWeakPasswordAndSendSecurityHeaders() throws Exception {
    mockMvc.perform(post("/api/users")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new CreateUserPayload(
            "weak-password-user", "weak-password@myaaptha.ai", "+15550119999", "password"))))
      .andExpect(status().isBadRequest())
      .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.header()
          .string("X-Content-Type-Options", "nosniff"))
      .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.header()
          .string("X-Frame-Options", "DENY"))
      .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.header()
          .string("Content-Security-Policy", org.hamcrest.Matchers.containsString("default-src 'none'")));
  }

  @Test
  void shouldAllowContactProviderCallbackWithoutAccessToken() throws Exception {
    mockMvc.perform(get("/api/contact-organizer/oauth/callback/google")
        .param("state", "expired-test-state"))
      .andExpect(status().isOk())
      .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content()
          .string(org.hamcrest.Matchers.containsString("authorization expired")));
  }

  @Test
  void shouldRejectLoginWithInvalidCredentials() throws Exception {
    createUser("auth-bad-user", "auth-bad@myaaptha.ai", "secret123");

    mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-bad@myaaptha.ai", "wrong-pass"))))
      .andExpect(status().isUnauthorized());
  }

  @Test
  void shouldRejectUnknownAndMalformedInputBeforeAuthentication() throws Exception {
    mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"email\":\"valid@example.com\",\"password\":\"secret123\",\"unexpected\":true}"))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.message").value("Malformed JSON or unsupported request field"));

    mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("{\"email\":\"not-an-email\",\"password\":\"secret123\"}"))
      .andExpect(status().isBadRequest());
  }

  @Test
  void shouldRequireAdministratorForDashboardSummary() throws Exception {
    createUser("auth-dashboard-user", "auth-dashboard@myaaptha.ai", "secret123");

    mockMvc.perform(get("/api/dashboard/summary"))
      .andExpect(status().isUnauthorized());

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-dashboard@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andReturn();

    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    mockMvc.perform(get("/api/dashboard/summary")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + loginPayload.accessToken))
      .andExpect(status().isForbidden());
  }

  @Test
  void shouldRequireAccessTokenForSessionProfile() throws Exception {
    createUser("auth-me-user", "auth-me@myaaptha.ai", "secret123");

    mockMvc.perform(get("/api/auth/me"))
      .andExpect(status().isUnauthorized());

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-me@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andReturn();

    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    mockMvc.perform(get("/api/auth/me")
        .header(HttpHeaders.AUTHORIZATION, "Bearer " + loginPayload.accessToken))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.id", not(nullValue())))
      .andExpect(jsonPath("$.username").value("auth-me-user"))
      .andExpect(jsonPath("$.email").value("auth-me@myaaptha.ai"));
  }

  @Test
  void shouldLogoutAndRevokeRefreshToken() throws Exception {
    createUser("auth-logout-user", "auth-logout@myaaptha.ai", "secret123");

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-logout@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andReturn();

    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    mockMvc.perform(post("/api/auth/logout")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(loginPayload.refreshToken))))
      .andExpect(status().isNoContent());

    mockMvc.perform(post("/api/auth/refresh")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(loginPayload.refreshToken))))
      .andExpect(status().isUnauthorized());
  }

  @Test
  void shouldRevokeRefreshTokenExplicitly() throws Exception {
    createUser("auth-revoke-user", "auth-revoke@myaaptha.ai", "secret123");

    MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("auth-revoke@myaaptha.ai", "secret123"))))
      .andExpect(status().isOk())
      .andReturn();

    TokenPayload loginPayload = objectMapper.readValue(loginResult.getResponse().getContentAsString(), TokenPayload.class);

    mockMvc.perform(post("/api/auth/revoke")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(loginPayload.refreshToken))))
      .andExpect(status().isNoContent());

    mockMvc.perform(post("/api/auth/refresh")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(loginPayload.refreshToken))))
      .andExpect(status().isUnauthorized());
  }

  @Test
  void unsignedForgedAndMalformedTokensCannotAuthenticate() throws Exception {
    String unsigned = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
        "{\"alg\":\"none\",\"typ\":\"JWT\"}".getBytes(java.nio.charset.StandardCharsets.UTF_8)) + "." +
        java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
        "{\"sub\":\"1\",\"role\":\"ADMIN\",\"exp\":4102444800}".getBytes(java.nio.charset.StandardCharsets.UTF_8)) + ".";
    for (String attack : java.util.List.of(unsigned, unsigned + "forged", "not-a-token", "a.b.c")) {
      mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + attack))
          .andExpect(status().isUnauthorized());
    }
  }

  @Test
  void browserMutationsRejectMissingOrHostileOriginAndMissingCsrfHeader() throws Exception {
    String payload = "{\"identifier\":\"nobody\",\"password\":\"WrongPassword123!\"}";
    mockMvc.perform(post("/api/web-auth/login").contentType(MediaType.APPLICATION_JSON).content(payload))
        .andExpect(status().isForbidden());
    mockMvc.perform(post("/api/web-auth/login").header("Origin", "https://attacker.invalid")
        .header("X-MyAaptha-Web", "1").contentType(MediaType.APPLICATION_JSON).content(payload))
        .andExpect(status().isForbidden());
    mockMvc.perform(post("/api/web-auth/login").header("Origin", "http://localhost:3000")
        .contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isForbidden());
  }

  @Test
  void logoutImmediatelyInvalidatesAccessTokenAndRefreshReplay() throws Exception {
    createUser("attack-revoke-user", "attack-revoke@myaaptha.ai", "secret123");
    var login = mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new LoginPayload("attack-revoke@myaaptha.ai", "secret123"))))
        .andExpect(status().isOk()).andReturn();
    var tokens = objectMapper.readValue(login.getResponse().getContentAsString(), TokenPayload.class);
    mockMvc.perform(post("/api/auth/logout").contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(tokens.refreshToken))))
        .andExpect(status().isNoContent());
    mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, "Bearer " + tokens.accessToken))
        .andExpect(status().isUnauthorized());
    mockMvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(tokens.refreshToken))))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void publicRegistrationCannotAssignAdministratorRole() throws Exception {
    mockMvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON)
        .content("{\"username\":\"mass-assignment\",\"phoneNumber\":\"+15550112233\",\"password\":\"StrongTest123!\",\"role\":\"ADMIN\"}"))
        .andExpect(status().isBadRequest());
  }

  private void createUser(String username, String email, String password) throws Exception {
    mockMvc.perform(post("/api/users")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new CreateUserPayload(username, email, "+1555" + Math.abs(username.hashCode()), password))))
      .andExpect(status().isOk());
  }

  @Test
  void independentDevicesSurviveLoginRefreshAndOtherDeviceLogout() throws Exception {
    createUser("multi-device-user", "multi-device@myaaptha.ai", "secret123");
    String body=objectMapper.writeValueAsString(new LoginPayload("multi-device@myaaptha.ai", "secret123"));
    var first=mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isOk()).andReturn();
    var mobile=objectMapper.readValue(first.getResponse().getContentAsString(),TokenPayload.class);
    var second=mockMvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isOk()).andReturn();
    var web=objectMapper.readValue(second.getResponse().getContentAsString(),TokenPayload.class);
    mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION,"Bearer "+mobile.accessToken))
        .andExpect(status().isOk());
    var refreshed=mockMvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(web.refreshToken))))
        .andExpect(status().isOk()).andReturn();
    web=objectMapper.readValue(refreshed.getResponse().getContentAsString(),TokenPayload.class);
    mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION,"Bearer "+mobile.accessToken))
        .andExpect(status().isOk());
    mockMvc.perform(post("/api/auth/logout").contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(new RefreshPayload(web.refreshToken))))
        .andExpect(status().isNoContent());
    mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION,"Bearer "+web.accessToken))
        .andExpect(status().isUnauthorized());
    mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION,"Bearer "+mobile.accessToken))
        .andExpect(status().isOk());
  }

  private record CreateUserPayload(String username, String email, String phoneNumber, String password) {
  }

  private record LoginPayload(String email, String password) {
  }

  private record RefreshPayload(String refreshToken) {
  }

  private static class TokenPayload {
    public String tokenType;
    public String accessToken;
    public String refreshToken;
    public long expiresIn;
  }
}
