package com.myaaptha.platform.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest(properties={"security.fields.enabled=true", "security.fields.allow-legacy-reads=true", "security.fields.keys=primary=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE="})
@AutoConfigureMockMvc
@Transactional
class NetworkPrivacyTest {
  @Autowired MockMvc mvc;
  @Autowired UserRepository users;
  @Autowired RelationshipRepository relationships;
  @Autowired org.springframework.security.crypto.password.PasswordEncoder passwords;
  @Autowired com.fasterxml.jackson.databind.ObjectMapper mapper;
  private UserEntity member() {
    var entity = new UserEntity(); entity.setUsername("privacy_" + java.util.UUID.randomUUID()); entity.setPasswordHash(passwords.encode("PrivacyTest123!"));
    return users.saveAndFlush(entity);
  }
  private String token(UserEntity member) throws Exception {
    var response = mvc.perform(post("/api/auth/login").contentType("application/json")
        .content(mapper.writeValueAsString(java.util.Map.of("identifier", member.getUsername(), "password", "PrivacyTest123!"))))
        .andExpect(status().isOk()).andReturn();
    return "Bearer " + mapper.readTree(response.getResponse().getContentAsString()).get("accessToken").asText();
  }
  @Test void bothViewsReceiveSameOwnerScopedContractWithoutLeakingPrivateContacts() throws Exception {
    var owner = member(); var stranger = member(); var relative = member();
    var relation = new RelationshipEntity(); relation.setType("Friend"); relation.setOwnerUserId(owner.getId()); relation.setRelatedUserId(relative.getId());
    relation.setContactPhone("+19995550123"); relationships.saveAndFlush(relation);
    mvc.perform(get("/api/network/relationships").header("Authorization", token(owner)))
        .andExpect(status().isOk()).andExpect(jsonPath("$[0].contactPhone").value("+19995550123"))
        .andExpect(jsonPath("$[0].person.id").value(relative.getId()));
    mvc.perform(get("/api/network/relationships").header("Authorization", token(stranger)))
        .andExpect(status().isOk()).andExpect(content().json("[]"));
    mvc.perform(get("/api/network/relationships")).andExpect(status().isUnauthorized());
  }

  @Test void onlyTheOwnerCanReadAndDeleteEncryptedFinancialRecords() throws Exception {
    String owner = token(member()), stranger = token(member());
    var created = mvc.perform(post("/api/finance/transactions").header("Authorization", owner)
        .contentType("application/json").content("{\"amount\":12.34,\"direction\":\"EXPENSE\",\"merchant\":\"Private fixture\"}"))
        .andExpect(status().isOk()).andReturn();
    long id = mapper.readTree(created.getResponse().getContentAsString()).get("id").asLong();
    mvc.perform(get("/api/finance/summary").header("Authorization", stranger))
        .andExpect(status().isOk()).andExpect(jsonPath("$.transactions").isEmpty());
    mvc.perform(delete("/api/finance/transactions/" + id).header("Authorization", stranger))
        .andExpect(status().isNotFound());
    mvc.perform(delete("/api/finance/transactions/" + id)).andExpect(status().isUnauthorized());
    mvc.perform(delete("/api/finance/transactions/" + id).header("Authorization", owner))
        .andExpect(status().isNoContent());
  }
}
