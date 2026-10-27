package com.myaaptha.domain.network.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateNetworkCircleRequest(@NotBlank @Size(max=120) String name, @Size(max=1000) String description) {}
