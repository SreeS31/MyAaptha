package com.myaaptha.platform.security;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import com.myaaptha.platform.state.ScheduledJobLock;
import com.myaaptha.domain.notification.WebhookNotificationProvider;
import java.util.*;
class SecurityAlertDispatcherTest {
 @Test void unconfiguredEmailKeepsQueueUntouched(){var jdbc=mock(JdbcTemplate.class);var provider=mock(WebhookNotificationProvider.class);new SecurityAlertDispatcher(jdbc,mock(ScheduledJobLock.class),provider,"").dispatch();verifyNoInteractions(jdbc,provider);}
 @Test void queuedAlertUsesDedicatedIdempotencyKey(){
  var jdbc=mock(JdbcTemplate.class);var lock=mock(ScheduledJobLock.class);var provider=mock(WebhookNotificationProvider.class);
  when(lock.acquire("security-alerts")).thenReturn(true);when(provider.configured()).thenReturn(true);when(provider.channel()).thenReturn("EMAIL");
  when(jdbc.queryForList(anyString(),any(java.sql.Timestamp.class))).thenReturn(List.of(Map.of("id",7L,"category","MALWARE","summary","Unsafe upload rejected")));
  new SecurityAlertDispatcher(jdbc,lock,provider,"admin@example.test").dispatch();
  verify(provider).send(any(),argThat(d->d.getDestination().equals("admin@example.test")&&d.getChannel().equals("EMAIL")),eq("myaaptha-security-7"));
  verify(jdbc).update(contains("email_status='SENT'"),eq(7L));
 }
 @Test void failedDeliveryIsRetriedWithoutIncludingProviderSecrets(){
  var jdbc=mock(JdbcTemplate.class);var lock=mock(ScheduledJobLock.class);var provider=mock(WebhookNotificationProvider.class);
  when(lock.acquire("security-alerts")).thenReturn(true);when(provider.configured()).thenReturn(true);when(provider.channel()).thenReturn("EMAIL");
  when(jdbc.queryForList(anyString(),any(java.sql.Timestamp.class))).thenReturn(List.of(Map.of("id",7L,"category","MALWARE","summary","Unsafe upload rejected")));
  when(provider.send(any(),any(),anyString())).thenThrow(new IllegalStateException("secret-provider-detail"));
  new SecurityAlertDispatcher(jdbc,lock,provider,"admin@example.test").dispatch();
  verify(jdbc).update(contains("email_attempts>=4"),any(java.sql.Timestamp.class),eq(7L));
 }
}
