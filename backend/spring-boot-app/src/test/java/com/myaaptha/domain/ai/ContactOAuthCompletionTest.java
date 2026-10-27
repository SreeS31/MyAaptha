package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;
import com.myaaptha.domain.contacts.AddressBookImportService;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

class ContactOAuthCompletionTest {
  final AddressBookImportService importer=mock(AddressBookImportService.class);
  final com.myaaptha.platform.state.LocalEphemeralState stateStore=new com.myaaptha.platform.state.LocalEphemeralState();
  final ContactOAuthStateStore oauthStore=ContactOAuthTestSupport.store(stateStore);
  final ContactOAuthService service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","id","secret","id","secret",importer,mock(AiPreferenceService.class),oauthStore);
  ContactOAuthService.StartResult start(){return service.start(42L,new ContactOAuthService.StartRequest("fixture@example.test","google"));}
  String state(ContactOAuthService.StartResult started){return UriComponentsBuilder.fromUriString(started.authorizationUrl()).build().getQueryParams().getFirst("state");}

  @Test void organizerDenialIsTerminalAndOwnerScopedWhilePrivateBookKeepsItsContract(){
    var started=start();
    service.callback("google",null,state(started),"access_denied");
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(43L,started.resultKey())).getStatusCode().value());
    var denied=assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey()));
    assertEquals(422,denied.getStatusCode().value());
    assertTrue(denied.getReason().contains("cancelled or denied"));
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getStatusCode().value());
    var book=service.startAddressBook(42L,new ContactOAuthService.StartRequest("fixture@example.test","google"),false);
    service.callback("google",null,state(book),"access_denied");
    assertEquals("failed",((Map<?,?>)service.consume(42L,book.resultKey())).get("status"));
    verifyNoInteractions(importer);
  }

  @Test void wrongProviderDoesNotConsumeThePendingAuthorization(){
    var started=start();
    service.callback("microsoft",null,state(started),"access_denied");
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getStatusCode().value());
    service.callback("google",null,state(started),"access_denied");
    assertEquals(422,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getStatusCode().value());
    verifyNoInteractions(importer);
  }

  @Test void emptyProviderContactsFinishAsAnEmptyReviewInsteadOfTimingOut(){
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    var started=start();
    server.expect(requestTo("https://oauth2.googleapis.com/token")).andRespond(withSuccess("{\"access_token\":\"fixture-token\"}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/contactGroups"))).andRespond(withSuccess("{\"contactGroups\":[]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/people/me/connections"))).andRespond(withSuccess("{\"connections\":[]}",MediaType.APPLICATION_JSON));
    service.callback("google","fixture-code",state(started),null);
    assertEquals(List.of(),service.consumeOrganizer(42L,started.resultKey()));
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getStatusCode().value());
    server.verify();verifyNoInteractions(importer);
  }

  @Test void providerFailureIsSafeAndTerminal(){
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    var started=start();server.expect(requestTo("https://oauth2.googleapis.com/token")).andRespond(withServerError());
    service.callback("google","fixture-code",state(started),null);
    var failure=assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey()));
    assertEquals(422,failure.getStatusCode().value());assertFalse(failure.getReason().contains("fixture-code"));
    server.verify();verifyNoInteractions(importer);
  }

  @Test void oversizedPreviewBecomesATerminalReviewErrorInsteadOfEndlessPending() {
    var store=spy(oauthStore);
    doThrow(new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE)).doCallRealMethod()
        .when(store).putResult(anyString(),eq(42L),any());
    ReflectionTestUtils.setField(service,"stateStore",store);
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    var started=start();
    server.expect(requestTo("https://oauth2.googleapis.com/token")).andRespond(withSuccess("{\"access_token\":\"fixture-token\"}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/contactGroups"))).andRespond(withSuccess("{\"contactGroups\":[]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/people/me/connections"))).andRespond(withSuccess("{\"connections\":[]}",MediaType.APPLICATION_JSON));
    service.callback("google","fixture-code",state(started),null);
    var failure=assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey()));
    assertEquals(422,failure.getStatusCode().value());assertTrue(failure.getReason().contains("too large"));
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getStatusCode().value());
    server.verify();verifyNoInteractions(importer);
  }

  @Test void revokedAnalysisPermissionStopsBeforeProviderTokenExchange(){
    var preferences=mock(AiPreferenceService.class);
    doThrow(new ResponseStatusException(HttpStatus.FORBIDDEN)).when(preferences).requireSensitiveDataAllowed(42L);
    ReflectionTestUtils.setField(service,"preferences",preferences);
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    var started=start();service.callback("google","fixture-code",state(started),null);
    var failure=assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey()));
    assertEquals(422,failure.getStatusCode().value());assertTrue(failure.getReason().contains("permission is disabled"));
    server.verify();verifyNoInteractions(importer);
  }

  @Test void revocationDuringProviderReadStopsBeforeAnalysis(){
    var preferences=mock(AiPreferenceService.class);
    doNothing().doThrow(new ResponseStatusException(HttpStatus.FORBIDDEN)).when(preferences).requireSensitiveDataAllowed(42L);
    ReflectionTestUtils.setField(service,"preferences",preferences);
    var builder=RestClient.builder();var server=MockRestServiceServer.bindTo(builder).build();ReflectionTestUtils.setField(service,"http",builder.build());
    var aiBuilder=RestClient.builder();var aiServer=MockRestServiceServer.bindTo(aiBuilder).build();ReflectionTestUtils.setField(service,"ai",aiBuilder.build());
    var started=start();
    server.expect(requestTo("https://oauth2.googleapis.com/token")).andRespond(withSuccess("{\"access_token\":\"fixture\"}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/contactGroups"))).andRespond(withSuccess("{\"contactGroups\":[]}",MediaType.APPLICATION_JSON));
    server.expect(requestTo(org.hamcrest.Matchers.startsWith("https://people.googleapis.com/v1/people/me/connections"))).andRespond(withSuccess("{\"connections\":[{\"names\":[{\"displayName\":\"Synthetic contact\"}]}]}",MediaType.APPLICATION_JSON));
    service.callback("google","fixture-code",state(started),null);
    assertTrue(assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,started.resultKey())).getReason().contains("permission is disabled"));
    verify(preferences,times(2)).requireSensitiveDataAllowed(42L);server.verify();aiServer.verify();verifyNoInteractions(importer);
  }

  @Test void idleMaintenancePrunesExpiredStateWithoutAClientReadButKeepsLiveFlows(){
    var now=java.time.Instant.parse("2026-10-18T00:00:00Z");
    ReflectionTestUtils.setField(oauthStore,"clock",java.time.Clock.fixed(now,java.time.ZoneOffset.UTC));
    ReflectionTestUtils.setField(stateStore,"clock",java.time.Clock.fixed(now,java.time.ZoneOffset.UTC));
    var completed=start();service.callback("google",null,state(completed),"access_denied");
    start();
    stateStore.cleanupExpired();
    assertEquals(2,((Map<?,?>)ReflectionTestUtils.getField(stateStore,"entries")).size());
    ReflectionTestUtils.setField(oauthStore,"clock",java.time.Clock.fixed(now.plusSeconds(601),java.time.ZoneOffset.UTC));
    ReflectionTestUtils.setField(stateStore,"clock",java.time.Clock.fixed(now.plusSeconds(601),java.time.ZoneOffset.UTC));
    stateStore.cleanupExpired();
    assertTrue(((Map<?,?>)ReflectionTestUtils.getField(stateStore,"entries")).isEmpty());
    assertEquals(404,assertThrows(ResponseStatusException.class,()->service.consumeOrganizer(42L,completed.resultKey())).getStatusCode().value());
    verifyNoInteractions(importer);
  }
}
