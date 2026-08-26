package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationEntity;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationRepository extends JpaRepository<NotificationEntity, Long> {
  List<NotificationEntity> findTop100ByUserIdOrderByCreatedAtDesc(Long userId);
  long countByUserIdAndReadAtIsNull(Long userId);
  Optional<NotificationEntity> findByIdAndUserId(Long id, Long userId);
}
