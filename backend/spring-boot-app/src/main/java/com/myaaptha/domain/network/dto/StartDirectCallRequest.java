package com.myaaptha.domain.network.dto;
public record StartDirectCallRequest(Long recipientId,String callType,String offerSdp) {}
