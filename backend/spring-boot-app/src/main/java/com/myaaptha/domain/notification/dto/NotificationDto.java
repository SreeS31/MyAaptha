package com.myaaptha.domain.notification.dto;

import java.time.Instant;
import java.util.List;

public record NotificationDto(Long id, String type, String title, String body, String actionUrl,
    String entityType, Long entityId, Instant readAt, Instant createdAt, List<DeliveryDto> deliveries) {
  public record DeliveryDto(String channel, String status, int attempts, String lastError, Instant sentAt) {}
}
