package com.myaaptha.domain.network.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record AddRelationshipRequest(@NotNull @Positive Long relatedUserId, @NotBlank @Size(max=80) String type,
    @NotBlank @Pattern(regexp="PUBLIC|FRIENDS|RELATIVES|COLLEAGUES") String visibilityScope,
    @Size(max=150) String visibilityCompany,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String milestoneDate,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String dateOfBirth,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String dateOfDeath) {}
