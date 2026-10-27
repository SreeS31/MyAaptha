package com.myaaptha.domain.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.*;
import com.myaaptha.domain.user.UserRepository;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest @AutoConfigureMockMvc
class PhoneRecoveryContractTest {
  @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired UserRepository users;@Autowired PasswordEncoder encoder;
  @MockitoBean PhoneVerificationService verification;
  @BeforeEach void setup(){when(verification.normalize(anyString())).thenAnswer(a->a.getArgument(0));}
  record Member(String username,String phone,long id){}
  Member member()throws Exception{
    String username="recovery-"+UUID.randomUUID(),phone="+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L));
    var result=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",username,"phoneNumber",phone,"password","OriginalSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(username,phone,json.readTree(result.getResponse().getContentAsString()).get("id").asLong());
  }
  @Test void policyHasSafeConfigurationMetadataWithoutProviderSecrets()throws Exception{
    when(verification.required()).thenReturn(true);when(verification.configured()).thenReturn(true);when(verification.verificationUrl()).thenReturn("https://app.example.invalid/verify-phone");
    mvc.perform(get("/api/auth/security-policy")).andExpect(status().isOk()).andExpect(jsonPath("$.phoneVerificationRequired").value(true)).andExpect(jsonPath("$.phoneVerificationConfigured").value(true)).andExpect(jsonPath("$.phoneVerificationUrl").value("https://app.example.invalid/verify-phone")).andExpect(jsonPath("$.secret").doesNotExist());
  }
  @Test void weakPasswordIsRejectedBeforeConsumingTheVerificationCode()throws Exception{
    mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("phoneNumber","+17780000000000","verificationCode","123456","password","OnlyLetters")))).andExpect(status().isBadRequest());
    verify(verification,never()).verify(anyString(),anyString());
  }
  @Test void verifiedRecoveryChangesPasswordAndRevokesExistingRefreshSession()throws Exception{
    var member=member();var auth=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",member.username(),"password","OriginalSecret123")))).andExpect(status().isOk()).andReturn();
    String refresh=json.readTree(auth.getResponse().getContentAsString()).get("refreshToken").asText();
    when(verification.verify(member.phone(),"123456")).thenReturn(true);
    mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("phoneNumber",member.phone(),"verificationCode","123456","password","NewSecret456")))).andExpect(status().isNoContent());
    assertTrue(encoder.matches("NewSecret456",users.findById(member.id()).orElseThrow().getPasswordHash()));
    mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("refreshToken",refresh)))).andExpect(status().isUnauthorized());
    mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",member.username(),"password","OriginalSecret123")))).andExpect(status().isUnauthorized());
  }
  @Test void unconfiguredRecoveryDoesNotChangePasswordAndUnknownOrAdminAccountsStayNeutral()throws Exception{
    var member=member();
    var payload=Map.of("phoneNumber",member.phone(),"verificationCode","123456","password","NewSecret456");
    mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(payload))).andExpect(status().isServiceUnavailable());
    assertTrue(encoder.matches("OriginalSecret123",users.findById(member.id()).orElseThrow().getPasswordHash()));
    var admin=users.findById(member.id()).orElseThrow();admin.setRole("ADMIN");users.saveAndFlush(admin);when(verification.verify(anyString(),eq("123456"))).thenReturn(true);
    mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(payload))).andExpect(status().isNoContent());
    assertTrue(encoder.matches("OriginalSecret123",users.findById(member.id()).orElseThrow().getPasswordHash()));
    mvc.perform(post("/api/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("phoneNumber","+17780000000000","verificationCode","123456","password","NewSecret456")))).andExpect(status().isNoContent());
  }
}
