package com.myaaptha.domain.network.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record AddPersonRequest(@NotBlank @Size(max=200) String fullName,
    @Pattern(regexp="^$|\\+?[0-9 ()-]{7,32}",message="must be a valid phone number") String phoneNumber,
    @Email @Size(max=254) String email, @NotBlank @Size(max=80) String type,
    @Pattern(regexp="PUBLIC|FRIENDS|RELATIVES|COLLEAGUES") String visibilityScope,
    @Size(max=150) String visibilityCompany,
    @Pattern(regexp="ACCOUNT|MANAGED") String identityType,
    @Pattern(regexp="CHILD|MEMORIAL|OTHER") String managedCategory,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String dateOfBirth,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String dateOfDeath,
    @Pattern(regexp="^$|\\d{4}-\\d{2}-\\d{2}") String milestoneDate,
    @Size(max=4000) String notes, @Positive Long relativeToUserId) {}
