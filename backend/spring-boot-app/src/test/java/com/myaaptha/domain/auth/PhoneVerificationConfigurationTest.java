package com.myaaptha.domain.auth;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.myaaptha.platform.state.EphemeralState;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
class PhoneVerificationConfigurationTest {
 @Test void incompleteConfigurationFailsBeforeAnyProviderOrBudgetAttempt(){
   var state=mock(EphemeralState.class);var service=new PhoneVerificationService(RestClient.builder(),state,true,"","","","","http://localhost:3000");
   assertFalse(service.configured());assertNull(service.verificationUrl());
   assertThrows(ResponseStatusException.class,()->service.start("+15551234567","challenge","127.0.0.1"));
   assertThrows(ResponseStatusException.class,()->service.verify("+15551234567","123456"));verifyNoInteractions(state);
 }
 @Test void configuredPolicyExposesOnlyThePublicVerificationPage(){
   var service=new PhoneVerificationService(RestClient.builder(),mock(EphemeralState.class),true,"test-account","test-secret","test-service","test-captcha","https://app.example.invalid");
   assertTrue(service.configured());assertEquals("https://app.example.invalid/verify-phone",service.verificationUrl());
 }
}
