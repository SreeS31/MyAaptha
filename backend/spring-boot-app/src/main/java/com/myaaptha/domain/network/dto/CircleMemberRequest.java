package com.myaaptha.domain.network.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CircleMemberRequest(@NotNull @Positive Long userId) {}
