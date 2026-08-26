package com.myaaptha.domain.notification.dto;

public record UpdateNotificationPreferenceRequest(boolean emailEnabled, boolean smsEnabled, boolean pushEnabled,
    boolean messagesEnabled, boolean circlesEnabled, boolean relationshipsEnabled,
    boolean callsEnabled, boolean invitationsEnabled, boolean socialEnabled) {}
