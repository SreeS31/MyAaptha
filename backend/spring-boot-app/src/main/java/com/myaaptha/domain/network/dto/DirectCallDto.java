package com.myaaptha.domain.network.dto;

import java.time.Instant;
public record DirectCallDto(Long id,Long callerId,Long recipientId,String callerName,String callerPhoto,
    String recipientName,String recipientPhoto,String callType,String status,String offerSdp,String answerSdp,
    Instant createdAt,Instant updatedAt,boolean currentUserCaller) {}
