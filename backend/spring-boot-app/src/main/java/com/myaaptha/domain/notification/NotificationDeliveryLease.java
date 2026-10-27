package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationDeliveryLease {
  private final NotificationDeliveryRepository repository;
  public NotificationDeliveryLease(NotificationDeliveryRepository repository){this.repository=repository;}
  @Transactional
  public Optional<NotificationDeliveryEntity> claim() {
    Instant now=Instant.now();var rows=repository.lockNext(now);
    if(rows.isEmpty())return Optional.empty();
    var delivery=rows.getFirst();
    if(delivery.getAttempts()>=5){delivery.setStatus("FAILED");delivery.setLastError("Delivery attempt limit reached");delivery.setLeaseUntil(null);delivery.setClaimToken(null);return Optional.empty();}
    delivery.setStatus("PROCESSING");delivery.setClaimToken(UUID.randomUUID().toString());
    delivery.setLeaseUntil(now.plusSeconds(60));delivery.setAttempts(delivery.getAttempts()+1);delivery.setUpdatedAt(now);
    return Optional.of(repository.saveAndFlush(delivery));
  }
  @Transactional
  public void finish(NotificationDeliveryEntity delivery,String status,String providerId,String error,Instant next) {
    repository.finish(delivery.getId(),delivery.getClaimToken(),status,providerId,error,
        "SENT".equals(status)?Instant.now():null,next,Instant.now());
  }
  @Transactional
  public void defer(NotificationDeliveryEntity delivery,Instant next) {
    repository.defer(delivery.getId(),delivery.getClaimToken(),next,Instant.now());
  }
}
