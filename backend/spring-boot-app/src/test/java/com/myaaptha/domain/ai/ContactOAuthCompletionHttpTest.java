package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.myaaptha.domain.contacts.AddressBookImportService;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

class ContactOAuthCompletionHttpTest {
  @Test void privateBookJsonContractSurvivesStorageAndANewServiceInstance() throws Exception {
    var backing=new com.myaaptha.platform.state.LocalEphemeralState();
    var firstStore=ContactOAuthTestSupport.store(backing);
    String key="A".repeat(43);
    var contact=new com.myaaptha.domain.contacts.AddressBookController.ContactInput("Synthetic contact",java.util.List.of("+15551230001"),java.util.List.of("fixture@example.test"),"Synthetic company",java.util.List.of("Friends"));
    firstStore.putResult(key,42L,Map.of("status","review","message","Review before saving","contacts",java.util.List.of(contact)));
    var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","id","secret","id","secret",mock(AddressBookImportService.class),mock(AiPreferenceService.class),ContactOAuthTestSupport.store(backing));
    var controller=new com.myaaptha.domain.contacts.AddressBookController(null,service,null,null);
    var mvc=MockMvcBuilders.standaloneSetup(controller).build();
    String path="/api/address-book/oauth/results/"+key;
    mvc.perform(get(path).principal(()->"43")).andExpect(status().isNotFound());
    mvc.perform(get(path).principal(()->"42")).andExpect(status().isOk())
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.status").value("review"))
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.contacts[0].displayName").value("Synthetic contact"))
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.contacts[0].phones[0]").value("+15551230001"))
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.contacts[0].emails[0]").value("fixture@example.test"))
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.contacts[0].groups[0]").value("Friends"));
    mvc.perform(get(path).principal(()->"42")).andExpect(status().isNotFound());
  }
  @Test void terminalDenialIsHttp422AndOtherOwnersCannotConsumeIt() throws Exception {
    var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","id","secret","id","secret",mock(AddressBookImportService.class),mock(AiPreferenceService.class),ContactOAuthTestSupport.store());
    var started=service.start(42L,new ContactOAuthService.StartRequest("fixture@example.test","google"));
    String state=UriComponentsBuilder.fromUriString(started.authorizationUrl()).build().getQueryParams().getFirst("state");
    service.callback("google",null,state,"access_denied");
    var controller=new ContactOrganizerController(RestClient.builder(),"http://unused",null,service,null,null);
    var mvc=MockMvcBuilders.standaloneSetup(controller).build();
    String path="/api/contact-organizer/oauth/results/"+started.resultKey();
    mvc.perform(get(path).principal(()->"43")).andExpect(status().isNotFound());
    var result=mvc.perform(get(path).principal(()->"42")).andExpect(status().isUnprocessableEntity()).andReturn();
    assertTrue(result.getResponse().getErrorMessage().contains("cancelled or denied"));
    mvc.perform(get(path).principal(()->"42")).andExpect(status().isNotFound());
  }
}
