package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationPreferenceEntity;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationPreferenceRepository extends JpaRepository<NotificationPreferenceEntity, Long> {
  Optional<NotificationPreferenceEntity> findByUnsubscribeToken(String token);
}
