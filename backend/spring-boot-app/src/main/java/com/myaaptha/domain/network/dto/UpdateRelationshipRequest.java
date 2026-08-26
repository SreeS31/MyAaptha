package com.myaaptha.domain.network.dto;

public record UpdateRelationshipRequest(String contactName, String contactPhone, String contactEmail, String type,
    String visibilityScope, String visibilityCompany, String milestoneDate, String dateOfBirth, String dateOfDeath) {}
