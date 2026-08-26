package com.myaaptha.domain.network.dto;

public record RelationshipImportRowResult(int rowNumber, String fullName, boolean success,
    String message, Long createdUserId, Long relationshipId) {}
