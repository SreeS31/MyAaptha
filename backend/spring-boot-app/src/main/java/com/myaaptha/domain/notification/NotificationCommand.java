package com.myaaptha.domain.notification;

public record NotificationCommand(Long userId, String type, String title, String body,
    String actionUrl, String entityType, Long entityId) {}
