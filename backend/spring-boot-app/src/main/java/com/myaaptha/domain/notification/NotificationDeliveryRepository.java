package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationDeliveryRepository extends JpaRepository<NotificationDeliveryEntity, Long> {
  @Query("select d from NotificationDeliveryEntity d where d.status in ('PENDING','RETRY') and d.nextAttemptAt <= :now order by d.createdAt")
  List<NotificationDeliveryEntity> findDue(@Param("now") Instant now, Pageable pageable);
  List<NotificationDeliveryEntity> findByNotificationId(Long notificationId);
}
