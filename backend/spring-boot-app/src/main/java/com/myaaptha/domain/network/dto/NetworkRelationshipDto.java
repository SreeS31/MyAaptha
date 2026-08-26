package com.myaaptha.domain.network.dto;

public record NetworkRelationshipDto(Long id, String type, String visibilityScope, String contactPhone, String contactEmail,
    String visibilityCompany, Long relativeToUserId, String milestoneDate, String dateOfBirth, String dateOfDeath,
    NetworkPersonDto person) {}
