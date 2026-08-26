package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationDeliveryDispatcher {
  private final NotificationDeliveryRepository deliveries;
  private final NotificationRepository notifications;
  private final List<NotificationChannelProvider> providers;
  public NotificationDeliveryDispatcher(NotificationDeliveryRepository deliveries,NotificationRepository notifications,List<NotificationChannelProvider> providers){this.deliveries=deliveries;this.notifications=notifications;this.providers=providers;}

  @Scheduled(fixedDelayString="${myaaptha.notifications.dispatch-delay-ms:5000}")
  @Transactional
  public void dispatch(){for(var delivery:deliveries.findDue(Instant.now(),PageRequest.of(0,50))) dispatch(delivery);}

  private void dispatch(NotificationDeliveryEntity delivery){
    var provider=providers.stream().filter(p->p.channel().equalsIgnoreCase(delivery.getChannel())).findFirst().orElse(null);
    if(provider==null||!provider.configured()){delivery.setStatus("SKIPPED");delivery.setLastError("No "+delivery.getChannel()+" provider is configured");delivery.setUpdatedAt(Instant.now());deliveries.save(delivery);return;}
    try{var notification=notifications.findById(delivery.getNotificationId()).orElseThrow();delivery.setProviderMessageId(provider.send(notification,delivery));delivery.setAttempts(delivery.getAttempts()+1);delivery.setStatus("SENT");delivery.setSentAt(Instant.now());delivery.setLastError(null);}
    catch(Exception error){int attempts=delivery.getAttempts()+1;delivery.setAttempts(attempts);delivery.setLastError(safe(error.getMessage()));if(attempts>=5)delivery.setStatus("FAILED");else{delivery.setStatus("RETRY");delivery.setNextAttemptAt(Instant.now().plus(backoff(attempts)));}}
    delivery.setUpdatedAt(Instant.now());deliveries.save(delivery);
  }
  private Duration backoff(int attempt){return switch(attempt){case 1->Duration.ofMinutes(1);case 2->Duration.ofMinutes(5);case 3->Duration.ofMinutes(30);default->Duration.ofHours(2);};}
  private String safe(String value){if(value==null)return "Provider delivery failed";return value.length()>1000?value.substring(0,1000):value;}
}
