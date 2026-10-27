package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationDeliveryRepository extends JpaRepository<NotificationDeliveryEntity, Long> {
  @org.springframework.data.jpa.repository.Modifying
  @Query("update NotificationDeliveryEntity d set d.status='RETRY',d.attempts=d.attempts-1,d.nextAttemptAt=:next,d.leaseUntil=null,d.claimToken=null,d.updatedAt=:now where d.id=:id and d.claimToken=:token and d.status='PROCESSING'")
  int defer(@Param("id") Long id,@Param("token") String token,@Param("next") Instant next,@Param("now") Instant now);
  @Query(value="SELECT * FROM notification_deliveries WHERE (status IN ('PENDING','RETRY') AND next_attempt_at <= :now) OR (status='PROCESSING' AND lease_until <= :now) ORDER BY next_attempt_at, id LIMIT 1 FOR UPDATE SKIP LOCKED", nativeQuery=true)
  List<NotificationDeliveryEntity> lockNext(@Param("now") Instant now);
  @org.springframework.data.jpa.repository.Modifying
  @Query("update NotificationDeliveryEntity d set d.status=:status,d.providerMessageId=:providerId,d.lastError=:error,d.sentAt=:sentAt,d.nextAttemptAt=:nextAttempt,d.updatedAt=:now,d.leaseUntil=null,d.claimToken=null where d.id=:id and d.claimToken=:token and d.status='PROCESSING'")
  int finish(@Param("id") Long id,@Param("token") String token,@Param("status") String status,
      @Param("providerId") String providerId,@Param("error") String error,@Param("sentAt") Instant sentAt,
      @Param("nextAttempt") Instant nextAttempt,@Param("now") Instant now);
  @Query("select d from NotificationDeliveryEntity d where d.status in ('PENDING','RETRY') and d.nextAttemptAt <= :now order by d.createdAt")
  List<NotificationDeliveryEntity> findDue(@Param("now") Instant now, Pageable pageable);
  List<NotificationDeliveryEntity> findByNotificationId(Long notificationId);
}
