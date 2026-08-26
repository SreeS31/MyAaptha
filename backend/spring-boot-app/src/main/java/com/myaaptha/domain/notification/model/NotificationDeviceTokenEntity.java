package com.myaaptha.domain.notification.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="notification_device_tokens")
public class NotificationDeviceTokenEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(name="user_id",nullable=false) private Long userId;
  @Column(nullable=false,unique=true,length=512) private String token;
  @Column(nullable=false,length=20) private String platform;
  @Column(nullable=false) private boolean enabled=true;
  @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
  @Column(name="updated_at",nullable=false) private Instant updatedAt=Instant.now();
  public Long getId(){return id;} public Long getUserId(){return userId;} public void setUserId(Long v){userId=v;} public String getToken(){return token;} public void setToken(String v){token=v;}
  public String getPlatform(){return platform;} public void setPlatform(String v){platform=v;} public boolean isEnabled(){return enabled;} public void setEnabled(boolean v){enabled=v;} public Instant getCreatedAt(){return createdAt;}
  public Instant getUpdatedAt(){return updatedAt;} public void setUpdatedAt(Instant v){updatedAt=v;}
}
