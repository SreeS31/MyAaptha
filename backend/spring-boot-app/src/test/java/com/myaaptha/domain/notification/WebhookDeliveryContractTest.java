package com.myaaptha.domain.notification;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import com.myaaptha.domain.notification.model.*;
import com.myaaptha.domain.settings.AppSettingsService;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.*;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestClient;

class WebhookDeliveryContractTest {
  HttpServer server;String endpoint;
  @BeforeEach void setup()throws Exception{server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);endpoint="http://127.0.0.1:"+server.getAddress().getPort()+"/delivery";server.start();}
  @AfterEach void stop(){server.stop(0);}
  NotificationEntity notification(){var n=new NotificationEntity();n.setUserId(1L);n.setTitle("Private fixture");n.setBody("Sensitive fixture body");return n;}
  NotificationDeliveryEntity delivery(){var d=new NotificationDeliveryEntity();ReflectionTestUtils.setField(d,"id",42L);d.setChannel("EMAIL");d.setDestination("recipient@example.invalid");d.setNotificationId(7L);d.setAttempts(1);return d;}
  WebhookNotificationProvider provider(){return new WebhookNotificationProvider(RestClient.builder(),"EMAIL",endpoint,"test-only-token");}

  @Test void postsExpectedContractAndStableIdempotencyKey()throws Exception{
    var headers=new AtomicReference<com.sun.net.httpserver.Headers>();var body=new AtomicReference<String>();
    server.createContext("/delivery",e->{headers.set(e.getRequestHeaders());body.set(new String(e.getRequestBody().readAllBytes(),StandardCharsets.UTF_8));e.getResponseHeaders().add("X-Provider-Message-Id","accepted-42");e.sendResponseHeaders(202,-1);e.close();});
    var p=provider();assertEquals("accepted-42",p.send(notification(),delivery()));assertEquals("accepted-42",p.send(notification(),delivery()));
    assertEquals("Bearer test-only-token",headers.get().getFirst("Authorization"));assertEquals("myaaptha-delivery-42",headers.get().getFirst("Idempotency-Key"));
    var payload=new com.fasterxml.jackson.databind.ObjectMapper().readTree(body.get());assertEquals("EMAIL",payload.get("channel").asText());assertEquals("recipient@example.invalid",payload.get("destination").asText());assertEquals("",payload.get("actionUrl").asText());
  }
  @Test void redirectIsNotDeliveryAcceptance(){
    server.createContext("/delivery",e->{e.getResponseHeaders().add("Location","/other");e.sendResponseHeaders(302,-1);e.close();});
    assertThrows(IllegalStateException.class,()->provider().send(notification(),delivery()));
  }
  @Test void redirectRemainsRetryableAndPayloadPreviewsRespectPreferences(){
    var body=new AtomicReference<String>();server.createContext("/delivery",e->{body.set(new String(e.getRequestBody().readAllBytes(),StandardCharsets.UTF_8));e.sendResponseHeaders(302,-1);e.close();});
    var leases=mock(NotificationDeliveryLease.class);var notices=mock(NotificationRepository.class);var service=mock(NotificationService.class);var settings=mock(AppSettingsService.class);var row=delivery();
    when(leases.claim()).thenReturn(Optional.of(row),Optional.empty());when(notices.findById(7L)).thenReturn(Optional.of(notification()));when(service.deliveryEnabled(any(),eq("EMAIL"))).thenReturn(true);when(settings.get(1L)).thenReturn(AppSettingsService.Settings.defaults());
    new NotificationDeliveryDispatcher(leases,notices,List.of(provider()),true,service,settings).dispatch();
    verify(leases).finish(eq(row),eq("RETRY"),isNull(),eq("Provider delivery failed"),any());
    assertFalse(body.get().contains("Sensitive fixture body"));assertFalse(body.get().contains("Private fixture"));assertTrue(body.get().contains("New MyAaptha notification"));
  }
  @Test void providerFailureExhaustsRetryBudgetWithoutSavingProviderErrorBodies(){
    var leases=mock(NotificationDeliveryLease.class);var notices=mock(NotificationRepository.class);var service=mock(NotificationService.class);var settings=mock(AppSettingsService.class);var p=mock(NotificationChannelProvider.class);var row=delivery();row.setAttempts(5);
    when(leases.claim()).thenReturn(Optional.of(row),Optional.empty());when(notices.findById(7L)).thenReturn(Optional.of(notification()));when(service.deliveryEnabled(any(),eq("EMAIL"))).thenReturn(true);when(settings.get(1L)).thenReturn(AppSettingsService.Settings.defaults());when(p.channel()).thenReturn("EMAIL");when(p.configured()).thenReturn(true);when(p.send(any(),any())).thenThrow(new IllegalStateException("Provider body may contain secrets"));
    new NotificationDeliveryDispatcher(leases,notices,List.of(p),true,service,settings).dispatch();
    verify(leases).finish(eq(row),eq("FAILED"),isNull(),eq("Provider delivery failed"),any());
  }
}
