package com.myaaptha.domain.message.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "relationship_broadcasts")
public class RelationshipBroadcastEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  private Long senderUserId;
  private String audienceType;
  private Long anchorUserId;
  private String locationQuery;
  private String messagePreview;
  private int recipientCount;
  private int failedCount;
  private Instant createdAt = Instant.now();
  public Long getId(){return id;} public Long getSenderUserId(){return senderUserId;} public void setSenderUserId(Long v){senderUserId=v;}
  public String getAudienceType(){return audienceType;} public void setAudienceType(String v){audienceType=v;} public Long getAnchorUserId(){return anchorUserId;} public void setAnchorUserId(Long v){anchorUserId=v;}
  public String getLocationQuery(){return locationQuery;} public void setLocationQuery(String v){locationQuery=v;} public String getMessagePreview(){return messagePreview;} public void setMessagePreview(String v){messagePreview=v;}
  public int getRecipientCount(){return recipientCount;} public void setRecipientCount(int v){recipientCount=v;} public int getFailedCount(){return failedCount;} public void setFailedCount(int v){failedCount=v;} public Instant getCreatedAt(){return createdAt;}
}
