package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.domain.contacts.AddressBookController.ContactInput;
import com.myaaptha.domain.contacts.AddressBookImportService;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

class ContactOAuthImportTest {
  ObjectMapper json=new ObjectMapper();
  @Test void googlePagesBeyond2000ResolveGroupNamesAndKeepResultsOwnerScoped()throws Exception {
    var importer=mock(AddressBookImportService.class);var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","google-id","google-secret","ms-id","ms-secret",importer,mock(AiPreferenceService.class),ContactOAuthTestSupport.store());
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    when(importer.save(eq(42L),anyList(),eq("google"),eq(true))).thenAnswer(call->{List<ContactInput> contacts=call.getArgument(1);assertEquals(List.of("College Friends"),contacts.getFirst().groups());return new AddressBookImportService.Outcome(contacts.size(),0,0,contacts.size(),0,contacts.size(),"Organized");});
    var started=service.startAddressBook(42L,new ContactOAuthService.StartRequest("person@example.test","google"),true);
    assertTrue(started.authorizationUrl().contains("contacts.readonly"));assertFalse(started.authorizationUrl().contains("google-secret"));
    String state=UriComponentsBuilder.fromUriString(started.authorizationUrl()).build().getQueryParams().getFirst("state");
    server.expect(requestTo("https://oauth2.googleapis.com/token")).andRespond(withSuccess("{\"access_token\":\"provider-token\"}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/contactGroups"))).andRespond(withSuccess("{\"contactGroups\":[{\"resourceName\":\"contactGroups/one\",\"name\":\"College Friends\",\"groupType\":\"USER_CONTACT_GROUP\"}]}",MediaType.APPLICATION_JSON));
    for(int page=0;page<3;page++){
      var contacts=new ArrayList<Map<String,Object>>();for(int i=0;i<(page==2?1:1000);i++)contacts.add(Map.of("names",List.of(Map.of("displayName","Contact "+(page*1000+i))),"phoneNumbers",List.of(Map.of("value","+15551234567")),"memberships",List.of(Map.of("contactGroupMembership",Map.of("contactGroupResourceName","contactGroups/one")))));
      Map<String,Object> response=new HashMap<>();response.put("connections",contacts);if(page<2)response.put("nextPageToken","page"+(page+1));
      server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/people/me/connections"))).andRespond(withSuccess(json.writeValueAsString(response),MediaType.APPLICATION_JSON));
    }
    service.callback("google","auth-code",state,null);assertThrows(ResponseStatusException.class,()->service.consume(43L,started.resultKey()));
    var result=(Map<?,?>)service.consume(42L,started.resultKey());assertEquals("review",result.get("status"));assertEquals(2001,((List<?>)result.get("contacts")).size());assertEquals(List.of("College Friends"),json.convertValue(((List<?>)result.get("contacts")).getFirst(),ContactInput.class).groups());verifyNoInteractions(importer);
    assertThrows(ResponseStatusException.class,()->service.consume(42L,started.resultKey()));server.verify();
  }
  @Test void providerDenialIsReturnedWithoutImportingAndReplayingStateDoesNothing(){
    var importer=mock(AddressBookImportService.class);var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","id","secret","id","secret",importer,mock(AiPreferenceService.class),ContactOAuthTestSupport.store());
    var started=service.startAddressBook(42L,new ContactOAuthService.StartRequest("person@example.test","google"),true);String state=UriComponentsBuilder.fromUriString(started.authorizationUrl()).build().getQueryParams().getFirst("state");
    service.callback("google",null,state,"access_denied");assertEquals("failed",((Map<?,?>)service.consume(42L,started.resultKey())).get("status"));service.callback("google","replay",state,null);verifyNoInteractions(importer);
  }
  @Test void outlookIncludesNestedFoldersCategoriesAndAllPhoneFields()throws Exception {
    var importer=mock(AddressBookImportService.class);var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","id","secret","id","secret",importer,mock(AiPreferenceService.class),ContactOAuthTestSupport.store());
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    when(importer.save(eq(42L),anyList(),eq("microsoft"),eq(true))).thenAnswer(call->{List<ContactInput> contacts=call.getArgument(1);assertEquals(2,contacts.size());assertEquals(List.of("+15551230001","+15551230002","+15551230003"),contacts.get(0).phones());assertTrue(contacts.get(1).groups().containsAll(List.of("Customers","College")));return new AddressBookImportService.Outcome(2,0,0,2,0,2,"Organized");});
    var started=service.startAddressBook(42L,new ContactOAuthService.StartRequest("person@example.test","microsoft"),true);String state=UriComponentsBuilder.fromUriString(started.authorizationUrl()).build().getQueryParams().getFirst("state");
    server.expect(requestTo("https://login.microsoftonline.com/common/oauth2/v2.0/token")).andRespond(withSuccess("{\"access_token\":\"provider-token\"}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contacts?"))).andRespond(withSuccess("{\"value\":[{\"id\":\"one\",\"displayName\":\"First\",\"mobilePhone\":\"+15551230001\",\"businessPhones\":[\"+15551230002\"],\"homePhones\":[\"+15551230003\"]}]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contactFolders?"))).andRespond(withSuccess("{\"value\":[{\"id\":\"folder-one\",\"displayName\":\"Friends\"}]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contactFolders/folder-one/contacts?"))).andRespond(withSuccess("{\"value\":[]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contactFolders/folder-one/childFolders?"))).andRespond(withSuccess("{\"value\":[{\"id\":\"folder-two\",\"displayName\":\"College\"}]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contactFolders/folder-two/contacts?"))).andRespond(withSuccess("{\"value\":[{\"id\":\"two\",\"displayName\":\"Second\",\"categories\":[\"Customers\"]}]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://graph.microsoft.com/v1.0/me/contactFolders/folder-two/childFolders?"))).andRespond(withSuccess("{\"value\":[]}",MediaType.APPLICATION_JSON));
    service.callback("microsoft","code",state,null);var result=(Map<?,?>)service.consume(42L,started.resultKey());var rows=(List<?>)result.get("contacts");assertEquals(2,rows.size());assertEquals(List.of("+15551230001","+15551230002","+15551230003"),json.convertValue(rows.getFirst(),ContactInput.class).phones());assertTrue(json.convertValue(rows.get(1),ContactInput.class).groups().containsAll(List.of("Customers","College")));verifyNoInteractions(importer);server.verify();
  }
}
