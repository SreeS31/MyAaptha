package com.myaaptha.domain.network.dto;

public record AddRelationshipRequest(Long relatedUserId, String type, String visibilityScope, String visibilityCompany,
    String milestoneDate, String dateOfBirth, String dateOfDeath) {}
