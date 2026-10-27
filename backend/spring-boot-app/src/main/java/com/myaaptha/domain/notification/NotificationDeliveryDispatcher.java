package com.myaaptha.domain.notification;

import java.time.Instant;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/** Durable at-least-once outbox: claim quickly, send outside the DB transaction. */
@Service
public class NotificationDeliveryDispatcher {
  private final NotificationDeliveryLease leases;
  private final NotificationRepository notifications;
  private final List<NotificationChannelProvider> providers;
  private final boolean enabled;
  private final NotificationService service;
  private final com.myaaptha.domain.settings.AppSettingsService settings;
  public NotificationDeliveryDispatcher(NotificationDeliveryLease leases,NotificationRepository notifications,
      List<NotificationChannelProvider> providers,@Value("${myaaptha.notifications.dispatch-enabled:true}") boolean enabled,
      NotificationService service,com.myaaptha.domain.settings.AppSettingsService settings) {
    this.leases=leases;this.notifications=notifications;this.providers=providers;this.enabled=enabled;this.service=service;this.settings=settings;
  }
  @Scheduled(fixedDelayString="${myaaptha.notifications.dispatch-delay-ms:5000}")
  public void dispatch() {
    if(!enabled)return;
    for(int i=0;i<50;i++) {
      var claimed=leases.claim();if(claimed.isEmpty())return;
      var delivery=claimed.get();
      var provider=providers.stream().filter(p->p.channel().equalsIgnoreCase(delivery.getChannel())).findFirst().orElse(null);
      if(provider==null||!provider.configured()) {
        leases.finish(delivery,"SKIPPED",null,"No provider is configured",Instant.now());continue;
      }
      try {
        var notification=notifications.findById(delivery.getNotificationId()).orElseThrow();
        if(!service.deliveryEnabled(notification,delivery.getChannel())) {
          leases.finish(delivery,"SKIPPED",null,"Disabled in notification preferences",Instant.now());continue;
        }
        var preference=settings.get(notification.getUserId());var now=Instant.now();
        var next=com.myaaptha.domain.settings.AppSettingsService.deliveryTime(preference,now);
        if(next.isAfter(now)){leases.defer(delivery,next);continue;}
        String id=provider.send(preference.notificationPreviews()?notification:notification.withoutPreview(),delivery);
        leases.finish(delivery,"SENT",id,null,Instant.now());
      } catch(Exception error) {
        int attempt=delivery.getAttempts();
        long seconds=switch(attempt){case 1->60;case 2->300;case 3->1800;default->7200;};
        // Do not persist provider error bodies, which can contain credentials/PII.
        leases.finish(delivery,attempt>=5?"FAILED":"RETRY",null,"Provider delivery failed",Instant.now().plusSeconds(seconds));
      }
    }
  }
}
