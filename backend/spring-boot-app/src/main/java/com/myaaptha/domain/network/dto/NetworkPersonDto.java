package com.myaaptha.domain.network.dto;

public record NetworkPersonDto(Long id, String firstName, String surname,
    String displayName, String phoneNumber, String location, String accountStatus, String profilePhoto,
    String identityType, String managedCategory, String claimStatus, String gender) {}
