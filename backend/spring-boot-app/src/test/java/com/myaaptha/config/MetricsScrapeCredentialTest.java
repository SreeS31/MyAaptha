package com.myaaptha.config;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class MetricsScrapeCredentialTest {
  final String token="synthetic-metrics-"+"a".repeat(48);
  @Test void disabledByDefault() {
    assertFalse(new MetricsScrapeCredential("").accepts("GET","/actuator/prometheus",token));
  }
  @Test void exactReadOnlyEndpointAndCredentialAreRequired() {
    var credential=new MetricsScrapeCredential(token);
    assertTrue(credential.accepts("GET","/actuator/prometheus",token));
    for(String path:new String[]{"/api/auth/me","/actuator/info","/actuator","/actuator/prometheus/extra"})
      assertFalse(credential.accepts("GET",path,token));
    assertFalse(credential.accepts("POST","/actuator/prometheus",token));
    assertFalse(credential.accepts("GET","/actuator/prometheus",token+"wrong"));
    assertFalse(credential.accepts("GET","/actuator/prometheus",null));
  }
  @Test void invalidConfiguredLengthsFailClosedWithoutEchoingCredential() {
    for(String invalid:new String[]{"short-private-value","x".repeat(513)}) {
      var error=assertThrows(IllegalStateException.class,()->new MetricsScrapeCredential(invalid));
      assertFalse(error.getMessage().contains(invalid));
    }
  }
}
