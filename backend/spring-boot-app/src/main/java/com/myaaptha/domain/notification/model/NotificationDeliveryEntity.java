package com.myaaptha.domain.notification.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="notification_deliveries")
public class NotificationDeliveryEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(name="notification_id",nullable=false) private Long notificationId;
  @Column(nullable=false,length=20) private String channel;
  @Column(nullable=false,length=512) private String destination;
  @Column(nullable=false,length=24) private String status="PENDING";
  @Column(nullable=false) private int attempts;
  @Column(name="next_attempt_at",nullable=false) private Instant nextAttemptAt=Instant.now();
  @Column(name="provider_message_id") private String providerMessageId;
  @Column(name="last_error",length=1000) private String lastError;
  @Column(name="sent_at") private Instant sentAt;
  @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
  @Column(name="updated_at",nullable=false) private Instant updatedAt=Instant.now();
  public Long getId(){return id;} public Long getNotificationId(){return notificationId;} public void setNotificationId(Long v){notificationId=v;} public String getChannel(){return channel;} public void setChannel(String v){channel=v;}
  public String getDestination(){return destination;} public void setDestination(String v){destination=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;} public int getAttempts(){return attempts;} public void setAttempts(int v){attempts=v;}
  public Instant getNextAttemptAt(){return nextAttemptAt;} public void setNextAttemptAt(Instant v){nextAttemptAt=v;} public String getProviderMessageId(){return providerMessageId;} public void setProviderMessageId(String v){providerMessageId=v;}
  public String getLastError(){return lastError;} public void setLastError(String v){lastError=v;} public Instant getSentAt(){return sentAt;} public void setSentAt(Instant v){sentAt=v;}
  public Instant getCreatedAt(){return createdAt;} public Instant getUpdatedAt(){return updatedAt;} public void setUpdatedAt(Instant v){updatedAt=v;}
}
