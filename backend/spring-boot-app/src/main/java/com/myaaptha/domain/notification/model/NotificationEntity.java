package com.myaaptha.domain.notification.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="notifications")
public class NotificationEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(name="user_id",nullable=false) private Long userId;
  @Column(nullable=false,length=40) private String type;
  @Column(nullable=false,length=180) private String title;
  @Column(nullable=false,length=2000) private String body;
  @Column(name="action_url",length=500) private String actionUrl;
  @Column(name="entity_type",length=40) private String entityType;
  @Column(name="entity_id") private Long entityId;
  @Column(name="read_at") private Instant readAt;
  @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
  public Long getId(){return id;} public Long getUserId(){return userId;} public void setUserId(Long v){userId=v;}
  public String getType(){return type;} public void setType(String v){type=v;} public String getTitle(){return title;} public void setTitle(String v){title=v;}
  public String getBody(){return body;} public void setBody(String v){body=v;} public String getActionUrl(){return actionUrl;} public void setActionUrl(String v){actionUrl=v;}
  public String getEntityType(){return entityType;} public void setEntityType(String v){entityType=v;} public Long getEntityId(){return entityId;} public void setEntityId(Long v){entityId=v;}
  public Instant getReadAt(){return readAt;} public void setReadAt(Instant v){readAt=v;} public Instant getCreatedAt(){return createdAt;} public void setCreatedAt(Instant v){createdAt=v;}
}
