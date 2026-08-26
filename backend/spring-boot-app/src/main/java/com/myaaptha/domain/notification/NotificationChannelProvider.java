package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import com.myaaptha.domain.notification.model.NotificationEntity;

public interface NotificationChannelProvider {
  String channel();
  boolean configured();
  String send(NotificationEntity notification, NotificationDeliveryEntity delivery);
}
