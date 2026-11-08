package com.myaaptha.domain.finance;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.assertThat;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.LocalDate;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Path;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest(properties="myaaptha.finance.renewal-reminders-enabled=false")
@AutoConfigureMockMvc @Transactional
class RenewalControllerTest {
  @TempDir static Path directory;
  @DynamicPropertySource static void mediaDirectory(DynamicPropertyRegistry registry){registry.add("myaaptha.storage.local-directory",()->directory.toString());}
  @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;@Autowired jakarta.persistence.EntityManager entityManager;
  String member()throws Exception{
    String name="renewal-api-"+UUID.randomUUID(),password="RenewalSecret123";
    mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password",password,"phoneNumber","+1776"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk());
    var response=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password",password)))).andExpect(status().isOk()).andReturn();
    return "Bearer "+json.readTree(response.getResponse().getContentAsString()).get("accessToken").asText();
  }
  Map<String,Object> input(){return new HashMap<>(Map.of("kind","BILL","title","Synthetic insurance renewal","expiresOn",LocalDate.now().plusDays(60).toString()));}
  @Test void defaultsCrudAndPrivateReceiptAreSharedByAllAuthenticatedClients()throws Exception{
    String owner=member(),other=member(),root="/api/finance/renewals";
    mvc.perform(get(root)).andExpect(status().is4xxClientError());
    var response=mvc.perform(post(root).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(input()))).andExpect(status().isCreated()).andExpect(jsonPath("$.remindersEnabled").value(true)).andExpect(jsonPath("$.timezone").value("Asia/Kolkata")).andReturn();
    long id=json.readTree(response.getResponse().getContentAsString()).get("id").asLong();String path=root+"/"+id;
    mvc.perform(get(root).header("Authorization",other)).andExpect(jsonPath("$.length()").value(0));
    mvc.perform(put(path+"/state").header("Authorization",other).contentType(MediaType.APPLICATION_JSON).content("{\"archived\":true}")).andExpect(status().isNotFound());
    mvc.perform(put(path+"/state").header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content("{\"archived\":true}")).andExpect(status().isOk()).andExpect(jsonPath("$.archived").value(true));
    mvc.perform(put(path+"/state").header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content("{\"archived\":false}")).andExpect(status().isOk()).andExpect(jsonPath("$.archived").value(false));
    mvc.perform(put(path).header("Authorization",other).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(input()))).andExpect(status().isNotFound());
    var pdf=new MockMultipartFile("file","invoice.pdf","application/pdf","%PDF-1.7\n1 0 obj\n<<>>\nendobj".getBytes());
    mvc.perform(multipart(path+"/attachment").file(pdf).param("retentionDays","7").header("Authorization",owner)).andExpect(status().isOk()).andExpect(jsonPath("$.attachmentName").value("invoice.pdf"));
    String finiteKey=jdbc.queryForObject("SELECT attachment_key FROM finance_renewals WHERE id=?",String.class,id);
    var deadline=jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,finiteKey);
    assertThat(deadline.toInstant()).isBetween(java.time.Instant.now().plusSeconds(7*86400L-20),java.time.Instant.now().plusSeconds(7*86400L+20));
    mvc.perform(get(path+"/attachment").header("Authorization",other)).andExpect(status().isNotFound());
    mvc.perform(get(path+"/attachment").header("Authorization",owner)).andExpect(status().isOk()).andExpect(header().string("Cache-Control","no-store")).andExpect(content().bytes(pdf.getBytes()));
    jdbc.update("UPDATE media_assets SET expires_at=? WHERE storage_key=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(1)),finiteKey);
    entityManager.clear();
    mvc.perform(get(path+"/attachment").header("Authorization",owner)).andExpect(status().isGone());
    mvc.perform(multipart(path+"/attachment").file(pdf).param("retentionDays","0").header("Authorization",owner)).andExpect(status().isOk());
    String neverKey=jdbc.queryForObject("SELECT attachment_key FROM finance_renewals WHERE id=?",String.class,id);
    assertThat(jdbc.queryForObject("SELECT expires_at FROM media_assets WHERE storage_key=?",java.sql.Timestamp.class,neverKey)).isNull();
    assertThat(directory.resolve(finiteKey)).doesNotExist();
    mvc.perform(get(path+"/attachment").header("Authorization",owner)).andExpect(status().isOk());
    mvc.perform(delete(path+"/attachment").header("Authorization",other)).andExpect(status().isNotFound());
    mvc.perform(delete(path+"/attachment").header("Authorization",owner)).andExpect(status().isNoContent());
    mvc.perform(get(path+"/attachment").header("Authorization",owner)).andExpect(status().isNotFound());
    mvc.perform(delete(path).header("Authorization",other)).andExpect(status().isNotFound());
    mvc.perform(delete(path).header("Authorization",owner)).andExpect(status().isNoContent());
    mvc.perform(get(root).header("Authorization",owner)).andExpect(jsonPath("$.length()").value(0));
  }
  @Test void invalidDatesAmountsAndZoneAreClientErrors()throws Exception{
    String owner=member(),root="/api/finance/renewals";
    for(var invalid:List.of(Map.of("expiresOn","2026-02-30"),Map.of("title"," "),Map.of("timezone","Invalid/Zone"),Map.of("amount",-1),Map.of("amount",1.234),Map.of("kind","UNKNOWN"))){
      var value=input();value.putAll(invalid);
      mvc.perform(post(root).header("Authorization",owner).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(value))).andExpect(status().isBadRequest());
    }
  }
}
