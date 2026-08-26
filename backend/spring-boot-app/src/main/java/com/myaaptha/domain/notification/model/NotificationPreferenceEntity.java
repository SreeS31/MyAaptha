package com.myaaptha.domain.notification.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="notification_preferences")
public class NotificationPreferenceEntity {
  @Id @Column(name="user_id") private Long userId;
  @Column(name="email_enabled",nullable=false) private boolean emailEnabled=true;
  @Column(name="sms_enabled",nullable=false) private boolean smsEnabled=true;
  @Column(name="push_enabled",nullable=false) private boolean pushEnabled=true;
  @Column(name="messages_enabled",nullable=false) private boolean messagesEnabled=true;
  @Column(name="circles_enabled",nullable=false) private boolean circlesEnabled=true;
  @Column(name="relationships_enabled",nullable=false) private boolean relationshipsEnabled=true;
  @Column(name="calls_enabled",nullable=false) private boolean callsEnabled=true;
  @Column(name="invitations_enabled",nullable=false) private boolean invitationsEnabled=true;
  @Column(name="social_enabled",nullable=false) private boolean socialEnabled=true;
  @Column(name="unsubscribe_token",nullable=false,unique=true,length=96) private String unsubscribeToken;
  @Column(name="updated_at",nullable=false) private Instant updatedAt=Instant.now();
  public Long getUserId(){return userId;} public void setUserId(Long v){userId=v;} public boolean isEmailEnabled(){return emailEnabled;} public void setEmailEnabled(boolean v){emailEnabled=v;}
  public boolean isSmsEnabled(){return smsEnabled;} public void setSmsEnabled(boolean v){smsEnabled=v;} public boolean isPushEnabled(){return pushEnabled;} public void setPushEnabled(boolean v){pushEnabled=v;}
  public boolean isMessagesEnabled(){return messagesEnabled;} public void setMessagesEnabled(boolean v){messagesEnabled=v;} public boolean isCirclesEnabled(){return circlesEnabled;} public void setCirclesEnabled(boolean v){circlesEnabled=v;}
  public boolean isRelationshipsEnabled(){return relationshipsEnabled;} public void setRelationshipsEnabled(boolean v){relationshipsEnabled=v;} public boolean isCallsEnabled(){return callsEnabled;} public void setCallsEnabled(boolean v){callsEnabled=v;}
  public boolean isInvitationsEnabled(){return invitationsEnabled;} public void setInvitationsEnabled(boolean v){invitationsEnabled=v;} public String getUnsubscribeToken(){return unsubscribeToken;} public void setUnsubscribeToken(String v){unsubscribeToken=v;}
  public boolean isSocialEnabled(){return socialEnabled;} public void setSocialEnabled(boolean v){socialEnabled=v;}
  public Instant getUpdatedAt(){return updatedAt;} public void setUpdatedAt(Instant v){updatedAt=v;}
}
