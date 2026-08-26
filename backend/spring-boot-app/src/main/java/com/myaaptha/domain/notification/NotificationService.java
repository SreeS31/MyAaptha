package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.dto.DeviceTokenRequest;
import com.myaaptha.domain.notification.dto.NotificationDto;
import com.myaaptha.domain.notification.dto.NotificationPreferenceDto;
import com.myaaptha.domain.notification.dto.UpdateNotificationPreferenceRequest;
import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import com.myaaptha.domain.notification.model.NotificationDeviceTokenEntity;
import com.myaaptha.domain.notification.model.NotificationEntity;
import com.myaaptha.domain.notification.model.NotificationPreferenceEntity;
import com.myaaptha.domain.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class NotificationService {
  private final NotificationRepository notifications;
  private final NotificationPreferenceRepository preferences;
  private final NotificationDeviceTokenRepository devices;
  private final NotificationDeliveryRepository deliveries;
  private final UserRepository users;

  public NotificationService(NotificationRepository notifications, NotificationPreferenceRepository preferences,
      NotificationDeviceTokenRepository devices, NotificationDeliveryRepository deliveries, UserRepository users) {
    this.notifications=notifications; this.preferences=preferences; this.devices=devices;
    this.deliveries=deliveries; this.users=users;
  }

  @Transactional
  public NotificationDto notify(NotificationCommand command) {
    var user=users.findById(command.userId()).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,"Notification recipient not found"));
    var preference=preference(command.userId());
    if (!categoryEnabled(preference, command.type())) return null;
    var item=new NotificationEntity(); item.setUserId(command.userId()); item.setType(normalize(command.type()));
    item.setTitle(command.title()); item.setBody(command.body()); item.setActionUrl(command.actionUrl());
    item.setEntityType(command.entityType()); item.setEntityId(command.entityId()); item=notifications.save(item);
    if (preference.isEmailEnabled() && hasText(user.getEmail())) queue(item.getId(),"EMAIL",user.getEmail());
    if (preference.isSmsEnabled() && hasText(user.getPhoneNumber())) queue(item.getId(),"SMS",user.getPhoneNumber());
    if (preference.isPushEnabled()) for (var device:devices.findByUserIdAndEnabledTrue(command.userId())) queue(item.getId(),"PUSH",device.getToken());
    return dto(item);
  }

  @Transactional(readOnly=true)
  public List<NotificationDto> inbox(Long userId) { return notifications.findTop100ByUserIdOrderByCreatedAtDesc(userId).stream().map(this::dto).toList(); }
  @Transactional(readOnly=true)
  public long unreadCount(Long userId) { return notifications.countByUserIdAndReadAtIsNull(userId); }

  @Transactional
  public NotificationDto markRead(Long userId, Long id) {
    var item=notifications.findByIdAndUserId(id,userId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,"Notification not found"));
    if(item.getReadAt()==null){item.setReadAt(Instant.now()); item=notifications.save(item);} return dto(item);
  }

  @Transactional
  public void markAllRead(Long userId) {
    var now=Instant.now();
    for(var item:notifications.findTop100ByUserIdOrderByCreatedAtDesc(userId)) if(item.getReadAt()==null){item.setReadAt(now); notifications.save(item);}
  }

  @Transactional public NotificationPreferenceDto preferences(Long userId){return preferenceDto(preference(userId));}

  @Transactional
  public NotificationPreferenceDto updatePreferences(Long userId, UpdateNotificationPreferenceRequest request) {
    var p=preference(userId); p.setEmailEnabled(request.emailEnabled()); p.setSmsEnabled(request.smsEnabled()); p.setPushEnabled(request.pushEnabled());
    p.setMessagesEnabled(request.messagesEnabled()); p.setCirclesEnabled(request.circlesEnabled()); p.setRelationshipsEnabled(request.relationshipsEnabled());
    p.setCallsEnabled(request.callsEnabled()); p.setInvitationsEnabled(request.invitationsEnabled()); p.setUpdatedAt(Instant.now());
    p.setSocialEnabled(request.socialEnabled());
    return preferenceDto(preferences.save(p));
  }

  @Transactional
  public void unsubscribe(String token) {
    var p=preferences.findByUnsubscribeToken(token).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,"Unsubscribe link is invalid or expired"));
    p.setEmailEnabled(false); p.setSmsEnabled(false); p.setPushEnabled(false); p.setUpdatedAt(Instant.now()); preferences.save(p);
  }

  @Transactional
  public void registerDevice(Long userId, DeviceTokenRequest request) {
    users.findById(userId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,"User not found"));
    var device=devices.findByToken(request.token()).orElseGet(NotificationDeviceTokenEntity::new);
    device.setUserId(userId); device.setToken(request.token()); device.setPlatform(request.platform().toUpperCase(Locale.ROOT));
    device.setEnabled(true); device.setUpdatedAt(Instant.now()); devices.save(device);
  }

  @Transactional
  public void unregisterDevice(Long userId, String token) {
    devices.findByToken(token).filter(d -> d.getUserId().equals(userId)).ifPresent(d -> {d.setEnabled(false); d.setUpdatedAt(Instant.now()); devices.save(d);});
  }

  private NotificationPreferenceEntity preference(Long userId){
    return preferences.findById(userId).orElseGet(() -> {var p=new NotificationPreferenceEntity(); p.setUserId(userId); p.setUnsubscribeToken(UUID.randomUUID().toString()); return preferences.save(p);});
  }
  private void queue(Long notificationId,String channel,String destination){var d=new NotificationDeliveryEntity();d.setNotificationId(notificationId);d.setChannel(channel);d.setDestination(destination);deliveries.save(d);}
  private boolean categoryEnabled(NotificationPreferenceEntity p,String type){return switch(normalize(type)){case "DIRECT_MESSAGE"->p.isMessagesEnabled();case "CIRCLE_MESSAGE"->p.isCirclesEnabled();case "RELATIONSHIP"->p.isRelationshipsEnabled();case "CALL"->p.isCallsEnabled();case "INVITATION"->p.isInvitationsEnabled();case "SOCIAL_LIKE","SOCIAL_COMMENT"->p.isSocialEnabled();default->true;};}
  private String normalize(String value){return value==null?"GENERAL":value.trim().toUpperCase(Locale.ROOT);}
  private boolean hasText(String value){return value!=null&&!value.isBlank();}
  private NotificationPreferenceDto preferenceDto(NotificationPreferenceEntity p){return new NotificationPreferenceDto(p.isEmailEnabled(),p.isSmsEnabled(),p.isPushEnabled(),p.isMessagesEnabled(),p.isCirclesEnabled(),p.isRelationshipsEnabled(),p.isCallsEnabled(),p.isInvitationsEnabled(),p.isSocialEnabled());}
  private NotificationDto dto(NotificationEntity n){var ds=deliveries.findByNotificationId(n.getId()).stream().map(d->new NotificationDto.DeliveryDto(d.getChannel(),d.getStatus(),d.getAttempts(),d.getLastError(),d.getSentAt())).toList();return new NotificationDto(n.getId(),n.getType(),n.getTitle(),n.getBody(),n.getActionUrl(),n.getEntityType(),n.getEntityId(),n.getReadAt(),n.getCreatedAt(),ds);}
}
