package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeviceTokenEntity;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationDeviceTokenRepository extends JpaRepository<NotificationDeviceTokenEntity, Long> {
  List<NotificationDeviceTokenEntity> findByUserIdAndEnabledTrue(Long userId);
  Optional<NotificationDeviceTokenEntity> findByToken(String token);
}
