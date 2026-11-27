package com.myaaptha.domain.contacts;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.domain.contacts.AddressBookController.ContactInput;
import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.CreateNetworkCircleRequest;
import java.util.*;import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.context.SpringBootTest;import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;import org.springframework.test.web.servlet.MockMvc;import org.springframework.http.MediaType;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.core.io.ClassPathResource;
@SpringBootTest @AutoConfigureMockMvc class AutomaticCirclePolicyTest{
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired AddressBookService book;@Autowired AddressBookCircleService circles;@Autowired NetworkService network;@Autowired JdbcTemplate db;
 long owner()throws Exception{var response=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username","circle-policy-"+UUID.randomUUID(),"password","CirclePolicySecret123","phoneNumber","+1776"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();return json.readTree(response.getResponse().getContentAsString()).get("id").asLong();}
 long contact(long owner,String name){return book.save(owner,List.of(new ContactInput(name,List.of(),List.of(),"",List.of())),"csv").contactIds().getFirst();}
 @Test void threeDistinctContactsAccumulateAcrossBatchesAndRetriesWithoutCrossingOwners()throws Exception{
  long user=owner(),other=owner(),a=contact(user,"A"),b=contact(user,"B"),c=contact(user,"C");
  assertThat(circles.organize(user,List.of(new AddressBookCircleService.Assignment(a,List.of("Office","office")),new AddressBookCircleService.Assignment(a,List.of("Office")))).circlesCreated()).isZero();
  assertThat(circles.organize(user,List.of(new AddressBookCircleService.Assignment(b,List.of("Office")))).circlesCreated()).isZero();assertThat(circles.list(user)).isEmpty();
  circles.organize(other,List.of(new AddressBookCircleService.Assignment(contact(other,"Other"),List.of("Office"))));assertThat(circles.list(other)).isEmpty();
  var result=circles.organize(user,List.of(new AddressBookCircleService.Assignment(c,List.of("Office"))));assertThat(result.circlesCreated()).isEqualTo(1);assertThat(result.contactsOrganized()).isEqualTo(3);assertThat(circles.list(user).getFirst().privateContactCount()).isEqualTo(3);
  assertThat(network.circles(user).getFirst().members()).hasSize(1);
  assertThat(circles.organize(user,List.of(new AddressBookCircleService.Assignment(c,List.of("Office")))).circlesCreated()).isZero();
 }
 @Test void manualSinglePersonCirclesRemainAllowedAndManualEditsClearPendingAssignments()throws Exception{
  long user=owner(),a=contact(user,"A"),b=contact(user,"B"),c=contact(user,"C");long manual=network.createCircle(user,new CreateNetworkCircleRequest("My solo circle",null)).id();
  circles.organize(user,List.of(new AddressBookCircleService.Assignment(a,List.of("Pending"))));circles.assign(user,a,List.of(manual));
  circles.organize(user,List.of(new AddressBookCircleService.Assignment(b,List.of("Pending")),new AddressBookCircleService.Assignment(c,List.of("Pending"))));assertThat(circles.list(user)).hasSize(1);assertThat(circles.list(user).getFirst().id()).isEqualTo(manual);
  assertThat(db.queryForObject("SELECT auto_organized FROM circles WHERE id=?",Boolean.class,manual)).isFalse();
 }
 @Test void legacyCleanupPreservesContactsManualCirclesAndAnyActivity()throws Exception{
  long user=owner(),a=contact(user,"A"),b=contact(user,"B");String description="Automatically organized private contacts. Only explicitly invited members can join conversations.";
  long generated=network.createCircle(user,new CreateNetworkCircleRequest("Small generated",description)).id(),manual=network.createCircle(user,new CreateNetworkCircleRequest("Manual",null)).id(),active=network.createCircle(user,new CreateNetworkCircleRequest("Active generated",description)).id();
  for(long id:List.of(generated,manual,active))db.update("INSERT INTO address_book_circle_contacts(contact_id,circle_id) VALUES(?,?)",a,id);
  db.update("INSERT INTO community_activities(circle_id,author_user_id,kind,title) VALUES(?,?,?,?)",active,user,"POLL","Keep this activity");
  String migration=new ClassPathResource("db/migration/common/V82__automatic_circle_minimum.sql").getContentAsString(StandardCharsets.UTF_8);String data=migration.substring(migration.indexOf("INSERT INTO address_book_circle_candidates"));
  data=data.replace("WHERE CHAR_LENGTH(c.name)","WHERE c.owner_user_id="+user+" AND CHAR_LENGTH(c.name)").replace("WHERE CHAR_LENGTH(name)","WHERE owner_user_id="+user+" AND CHAR_LENGTH(name)").replace("DELETE FROM circles WHERE auto_organized", "DELETE FROM circles WHERE owner_user_id="+user+" AND auto_organized");
  for(String sql:data.split(";"))if(!sql.isBlank())db.execute(sql);
  assertThat(db.queryForObject("SELECT COUNT(*) FROM circles WHERE id=?",Integer.class,generated)).isZero();assertThat(db.queryForObject("SELECT COUNT(*) FROM circles WHERE id IN (?,?)",Integer.class,manual,active)).isEqualTo(2);
  assertThat(book.allEntries(user)).hasSize(2);assertThat(db.queryForObject("SELECT COUNT(*) FROM address_book_circle_candidates WHERE owner_user_id=? AND normalized_name='small generated'",Integer.class,user)).isEqualTo(1);
 }
}
