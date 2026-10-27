package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationEntity;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<NotificationEntity, Long> {
  @org.springframework.data.jpa.repository.Modifying
  @org.springframework.data.jpa.repository.Query("update NotificationEntity n set n.readAt=:now where n.userId=:userId and n.readAt is null")
  int markAllRead(@org.springframework.data.repository.query.Param("userId") Long userId,
      @org.springframework.data.repository.query.Param("now") java.time.Instant now);
  List<NotificationEntity> findTop100ByUserIdOrderByCreatedAtDesc(Long userId);
  long countByUserIdAndReadAtIsNull(Long userId);
  Optional<NotificationEntity> findByIdAndUserId(Long id, Long userId);
}
