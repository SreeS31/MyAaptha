package com.myaaptha.domain.contacts;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:addressbook-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1","security.fields.enabled=true","security.fields.active-key-id=test","security.fields.keys=test=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="})
@AutoConfigureMockMvc
class AddressBookTest {
  @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate jdbc;
  static final AtomicReference<String> sent=new AtomicReference<>();static HttpServer ai;
  static {
    try{ai=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);ai.createContext("/contacts/organize",exchange->{
      var mapper=new ObjectMapper();var text=new String(exchange.getRequestBody().readAllBytes(),java.nio.charset.StandardCharsets.UTF_8);sent.set(text);
      var contacts=mapper.readTree(text).get("contacts");var output=new ArrayList<Map<String,Object>>();
      for(var contact:contacts)output.add(Map.of("contact_key",contact.get("contact_key").asText(),"suggested_circles",List.of("Family"),"confidence",0.9));
      byte[] body=mapper.writeValueAsBytes(output);exchange.getResponseHeaders().add("Content-Type","application/json");exchange.sendResponseHeaders(200,body.length);exchange.getResponseBody().write(body);exchange.close();
    });ai.start();}catch(Exception e){throw new ExceptionInInitializerError(e);}
  }
  @DynamicPropertySource static void properties(DynamicPropertyRegistry registry){registry.add("myaaptha.ai.base-url",()->"http://127.0.0.1:"+ai.getAddress().getPort());}
  @AfterAll static void close(){ai.stop(0);}
  record Member(long id,String bearer){}
  Member member()throws Exception{
    String name="contacts-"+UUID.randomUUID();var registered=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","ContactTestSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
    var auth=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","ContactTestSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(json.readTree(registered.getResponse().getContentAsString()).get("id").asLong(),"Bearer "+json.readTree(auth.getResponse().getContentAsString()).get("accessToken").asText());
  }
  Map<String,Object> contact(String name){return Map.of("displayName",name,"phones",List.of("+1555 123 4567","+15551239999"),"emails",List.of("private@example.test","second@example.test"),"organization","Example","groups",List.of("Family"));}
  String body(List<?> contacts,boolean organize)throws Exception{return json.writeValueAsString(Map.of("consent",true,"contacts",contacts,"source","csv","organize",organize));}
  @Test void reviewedImportSkipsInvalidRowsAndUsesOnlyChosenCircleNames()throws Exception{
    var owner=member();var valid=contact("Reviewed");
    var invalid=Map.of("displayName","Skip","phones",List.of("bad",""),"emails",List.of("email@example.test"));
    var rows=List.of(Map.of("contact",valid,"circleNames",List.of("INCOIS")),Map.of("contact",invalid,"circleNames",List.of("Never create")));
    mvc.perform(post("/api/address-book/import-reviewed").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("consent",true,"contacts",rows,"source","csv")))).andExpect(status().isOk()).andExpect(jsonPath("$.added").value(1)).andExpect(jsonPath("$.skipped").value(1));
    mvc.perform(get("/api/address-book/circles").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].name").value("INCOIS"));
  }
  @Test void importIsPrivateEncryptedIdempotentAndDoesNotCreateAccountsOrRelations()throws Exception{
    var owner=member();var stranger=member();long users=jdbc.queryForObject("SELECT COUNT(*) FROM users",Long.class),relations=jdbc.queryForObject("SELECT COUNT(*) FROM relationships",Long.class);
    String body=body(List.of(contact("Mom"),contact("Mom")),false);
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.added").value(1)).andExpect(jsonPath("$.unchanged").value(1));
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.added").value(0));
    var result=mvc.perform(get("/api/address-book?q=mom").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.items[0].phones.length()").value(2)).andExpect(jsonPath("$.items[0].emails.length()").value(2)).andExpect(jsonPath("$.total").value(1)).andReturn();
    long id=json.readTree(result.getResponse().getContentAsString()).at("/items/0/id").asLong();
    String stored=jdbc.queryForObject("SELECT contact_data FROM address_book_contacts WHERE id=?",String.class,id);assertTrue(stored.startsWith("enc:v1:"));assertFalse(stored.contains("private@example.test"));
    assertEquals(users,jdbc.queryForObject("SELECT COUNT(*) FROM users",Long.class));assertEquals(relations,jdbc.queryForObject("SELECT COUNT(*) FROM relationships",Long.class));
    mvc.perform(get("/api/address-book").header("Authorization",stranger.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.total").value(0));
    mvc.perform(delete("/api/address-book/"+id).header("Authorization",stranger.bearer())).andExpect(status().isNotFound());
    mvc.perform(post("/api/address-book/"+id+"/relation").header("Authorization",stranger.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"consent\":true,\"relationship\":\"Other\"}")).andExpect(status().isNotFound());
    mvc.perform(delete("/api/address-book").header("Authorization",owner.bearer())).andExpect(status().isBadRequest());
    mvc.perform(delete("/api/address-book?confirm=true").header("Authorization",owner.bearer())).andExpect(status().isOk());
    assertEquals(0L,jdbc.queryForObject("SELECT COUNT(*) FROM address_book_contacts WHERE user_id=?",Long.class,owner.id()));
  }
  @Test void automaticCirclesReuseOwnedNamesAndPreserveManualCorrections()throws Exception{
    var owner=member();var another=member();
    for(var member:List.of(owner,another))mvc.perform(post("/api/network/circles").header("Authorization",member.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Family\",\"description\":\"Existing family circle\"}")).andExpect(status().isOk());
    mvc.perform(put("/api/ai/preferences").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"aiEnabled\":true,\"allowSensitiveData\":true,\"allowPersonalization\":false,\"activityRetentionDays\":0}")).andExpect(status().isOk());
    String body=body(List.of(contact("Mom")),true);
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.circlesCreated").value(0)).andExpect(jsonPath("$.contactsOrganized").value(1));
    assertFalse(sent.get().contains("private@example.test"));assertFalse(sent.get().contains("+1555"));
    var response=mvc.perform(get("/api/address-book").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.items[0].circleIds.length()").value(1)).andReturn();long id=json.readTree(response.getResponse().getContentAsString()).at("/items/0/id").asLong();
    mvc.perform(get("/api/address-book/circles").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].privateContactCount").value(1));
    mvc.perform(put("/api/address-book/"+id+"/circles").header("Authorization",another.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"circleIds\":[]}")).andExpect(status().isNotFound());
    mvc.perform(put("/api/address-book/"+id+"/circles").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"circleIds\":[]}")).andExpect(status().isOk());
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.contactsOrganized").value(0));
    assertEquals(0L,jdbc.queryForObject("SELECT COUNT(*) FROM address_book_circle_contacts WHERE contact_id=?",Long.class,id));
    assertEquals(1L,jdbc.queryForObject("SELECT COUNT(*) FROM circle_members m JOIN circles c ON c.id=m.circle_id WHERE c.owner_user_id=?",Long.class,owner.id()));
  }
  @Test void validationPaginationAndAiDisabledFallback()throws Exception{
    var owner=member();
    mvc.perform(get("/api/address-book")).andExpect(status().isUnauthorized());
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body(List.of(contact("Name")),false).replace("\"consent\":true","\"consent\":false"))).andExpect(status().isBadRequest());
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body(Collections.nCopies(101,contact("Too many")),false))).andExpect(status().isBadRequest());
    mvc.perform(post("/api/address-book/import").header("Authorization",owner.bearer()).contentType(MediaType.APPLICATION_JSON).content(body(List.of(contact("Alpha"),contact("Beta")),true))).andExpect(status().isOk()).andExpect(jsonPath("$.added").value(2)).andExpect(jsonPath("$.contactsOrganized").value(0));
    var first=mvc.perform(get("/api/address-book?limit=1").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(1)).andExpect(jsonPath("$.nextCursor").isNumber()).andReturn();long cursor=json.readTree(first.getResponse().getContentAsString()).get("nextCursor").asLong();
    mvc.perform(get("/api/address-book?limit=1&afterId="+cursor).header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.items[0].displayName").value("Beta")).andExpect(jsonPath("$.nextCursor").doesNotExist());
    mvc.perform(get("/api/address-book?limit=101").header("Authorization",owner.bearer())).andExpect(status().isBadRequest());
    mvc.perform(get("/api/address-book?q=%25").header("Authorization",owner.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(0));
  }
}
