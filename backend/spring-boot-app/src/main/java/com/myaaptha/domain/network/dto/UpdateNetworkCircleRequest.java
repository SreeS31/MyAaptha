package com.myaaptha.domain.network.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UpdateNetworkCircleRequest(@NotBlank @Size(max=120) String name, @Size(max=1000) String description,
    @Pattern(regexp="ALL_MEMBERS|ADMINS_ONLY") String postingPermission) {}
