package com.myaaptha.domain.finance;
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
@SpringBootTest @AutoConfigureMockMvc
class FinanceInputContractTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;
 String member()throws Exception{String name="finance-input-"+UUID.randomUUID();mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","InputSecret123","phoneNumber","+1777"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk());var r=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","InputSecret123")))).andExpect(status().isOk()).andReturn();return "Bearer "+json.readTree(r.getResponse().getContentAsString()).get("accessToken").asText();}
 @Test void invalidMonthsAreClientErrorsAndFutureTransactionsRemainRejected()throws Exception{
   String token=member();
   for(String month:List.of("invalid","2026-13","2026-00","0000-01","2026-1"))mvc.perform(get("/api/finance/summary").param("month",month).header("Authorization",token)).andExpect(status().isBadRequest());
   mvc.perform(get("/api/finance/summary").param("month","2026-09").header("Authorization",token)).andExpect(status().isOk());
   mvc.perform(post("/api/finance/transactions").header("Authorization",token).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("amount",10,"direction","EXPENSE","category","OTHER","source","MANUAL","occurredAt",java.time.Instant.now().plusSeconds(86400).toString())))).andExpect(status().isBadRequest());
 }
}
