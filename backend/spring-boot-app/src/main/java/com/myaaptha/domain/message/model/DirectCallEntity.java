package com.myaaptha.domain.message.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="direct_calls")
public class DirectCallEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(name="caller_user_id",nullable=false) private Long callerUserId;
  @Column(name="recipient_user_id",nullable=false) private Long recipientUserId;
  @Column(name="call_type",nullable=false,length=16) private String callType;
  @Column(nullable=false,length=24) private String status="RINGING";
  @Column(name="offer_sdp",nullable=false,columnDefinition="TEXT") private String offerSdp;
  @Column(name="answer_sdp",columnDefinition="TEXT") private String answerSdp;
  @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
  @Column(name="updated_at",nullable=false) private Instant updatedAt=Instant.now();
  public Long getId(){return id;}
  public Long getCallerUserId(){return callerUserId;} public void setCallerUserId(Long value){callerUserId=value;}
  public Long getRecipientUserId(){return recipientUserId;} public void setRecipientUserId(Long value){recipientUserId=value;}
  public String getCallType(){return callType;} public void setCallType(String value){callType=value;}
  public String getStatus(){return status;} public void setStatus(String value){status=value;}
  public String getOfferSdp(){return offerSdp;} public void setOfferSdp(String value){offerSdp=value;}
  public String getAnswerSdp(){return answerSdp;} public void setAnswerSdp(String value){answerSdp=value;}
  public Instant getCreatedAt(){return createdAt;}
  public Instant getUpdatedAt(){return updatedAt;} public void setUpdatedAt(Instant value){updatedAt=value;}
}
