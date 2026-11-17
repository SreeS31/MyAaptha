package com.myaaptha.domain.interests;
import java.util.*;
import java.util.stream.IntStream;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.assertj.core.api.Assertions.*;
@SpringBootTest @AutoConfigureMockMvc
class InterestGroupTest {
 @Autowired MockMvc mvc; @Autowired ObjectMapper json; @Autowired InterestGroupService service; @Autowired UserProfileRepository profiles;
 record Account(long id,String token){}
 Account account()throws Exception {String name="interest"+UUID.randomUUID().toString().replace("-","");var created=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"email",name+"@example.test","phoneNumber","+1999"+String.format("%010d",new java.security.SecureRandom().nextLong(10000000000L)),"password","Synthetic-password-17!")))).andExpect(status().isOk()).andReturn();long id=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","Synthetic-password-17!")))).andExpect(status().isOk()).andReturn();return new Account(id,json.readTree(login.getResponse().getContentAsString()).get("accessToken").asText());}
 MockHttpServletRequestBuilder as(MockHttpServletRequestBuilder request,Account a){return request.header("Authorization","Bearer "+a.token());}
 String create(Account a,String area)throws Exception{var response=mvc.perform(as(post("/api/interests/groups"),a).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("name","Hyderabad Cycle Club","topic","Cycling","area",area,"description","Weekend rides and safe cycling discussions")))).andExpect(status().isOk()).andExpect(jsonPath("$.admin").value(true)).andExpect(jsonPath("$.membership").value("ACTIVE")).andReturn();return json.readTree(response.getResponse().getContentAsString()).get("id").asText();}
 @Test void approvedMembershipControlsDiscussionAndOnlyCreatorCanApproveOrEdit()throws Exception{
  var owner=account();var member=account();var outsider=account();String id=create(owner,"Hyderabad");String base="/api/interests/groups/"+id;
  mvc.perform(get(base)).andExpect(status().isUnauthorized());
  mvc.perform(as(get("/api/interests/groups").param("area","hyderabad").param("topic","Cycling"),member)).andExpect(status().isOk()).andExpect(jsonPath("$.items[0].id").value(id));
  mvc.perform(as(get(base+"/messages"),member)).andExpect(status().isForbidden());
  mvc.perform(as(post(base+"/join"),member)).andExpect(status().isOk()).andExpect(jsonPath("$.membership").value("REQUESTED"));
  mvc.perform(as(post(base+"/join"),member)).andExpect(status().isOk());
  mvc.perform(as(post(base+"/messages"),member).contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"Not approved\"}")).andExpect(status().isForbidden());
  mvc.perform(as(get(base+"/requests"),outsider)).andExpect(status().isForbidden());
  mvc.perform(as(put(base+"/requests/"+member.id()),outsider).contentType(MediaType.APPLICATION_JSON).content("{\"approve\":true}")).andExpect(status().isForbidden());
  mvc.perform(as(get(base+"/requests"),owner)).andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(1));
  mvc.perform(as(put(base+"/requests/"+member.id()),owner).contentType(MediaType.APPLICATION_JSON).content("{\"approve\":true}")).andExpect(status().isOk());
  mvc.perform(as(post(base+"/messages"),member).contentType(MediaType.APPLICATION_JSON).content("{\"body\":\"Sunday ride at 7 am?\"}")).andExpect(status().isOk());
  var result=mvc.perform(as(get(base+"/messages"),owner)).andExpect(status().isOk()).andExpect(jsonPath("$.items[0].body").value("Sunday ride at 7 am?")).andReturn();String message=json.readTree(result.getResponse().getContentAsString()).at("/items/0/id").asText();
  mvc.perform(as(delete(base+"/messages/"+message),outsider)).andExpect(status().isForbidden());
  mvc.perform(as(put(base),member).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Hijacked\",\"topic\":\"Cycling\",\"area\":\"India\",\"description\":\"No\"}")).andExpect(status().isForbidden());
  mvc.perform(as(delete(base+"/messages/"+message),owner)).andExpect(status().isOk());
  mvc.perform(as(delete(base+"/membership"),member)).andExpect(status().isOk());
  mvc.perform(as(get(base+"/messages"),member)).andExpect(status().isForbidden());
  mvc.perform(as(delete(base+"/membership"),owner)).andExpect(status().isBadRequest());
 }
 @Test void interestsHaveNoSelectionQuotaAndPreserveUnrelatedProfileFields()throws Exception{
  var a=account();var b=account();var p=new UserProfileEntity();p.setUserId(a.id());p.setEmployer("Keep career data");profiles.save(p);
  var choices=new ArrayList<>(IntStream.range(0,350).mapToObj(i->"Interest "+i).toList());choices.add("interest 0");
  mvc.perform(as(put("/api/interests/me"),a).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("interests",choices)))).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(350));
  assertThat(profiles.findById(a.id()).orElseThrow().getEmployer()).isEqualTo("Keep career data");
  mvc.perform(as(get("/api/interests/me"),b)).andExpect(jsonPath("$.length()").value(0));
  mvc.perform(as(put("/api/interests/me"),a).contentType(MediaType.APPLICATION_JSON).content("{\"interests\":[]}")).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
 }
 @Test void directoryPaginatesWithoutLimitingGroupCreationOrMembership()throws Exception{
  var owner=account();var member=account();String area="testarea"+UUID.randomUUID();
  for(int i=0;i<27;i++){String id=create(owner,area);service.request(member.id(),id);service.decide(owner.id(),id,member.id(),true);}
  var first=service.directory(member.id(),"",area,"",true,0);var second=service.directory(member.id(),"",area,"",true,1);
  assertThat(first.items()).hasSize(24);assertThat(first.hasNext()).isTrue();assertThat(second.items()).hasSize(3);assertThat(second.hasNext()).isFalse();
  assertThat(service.directory(member.id(),"%",area,"",false,0).items()).isEmpty();
 }
 @Test void rejectedRequestsCanBeResubmittedAndMissingOrMalformedInputsAreRejected()throws Exception{
  var owner=account();var member=account();String id=create(owner,"India");service.request(member.id(),id);service.decide(owner.id(),id,member.id(),false);
  assertThat(service.request(member.id(),id).membership()).isEqualTo("REQUESTED");
  mvc.perform(as(get("/api/interests/groups").param("page","-1"),member)).andExpect(status().isBadRequest());
  mvc.perform(as(post("/api/interests/groups/missing/join"),member)).andExpect(status().isNotFound());
  mvc.perform(as(post("/api/interests/groups"),member).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\" \",\"topic\":\"Cycling\",\"area\":\"India\",\"description\":\"test\"}")).andExpect(status().isBadRequest());
 }
}
