package com.myaaptha.domain.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record DeviceTokenRequest(@NotBlank String token,
    @Pattern(regexp="ANDROID|IOS|WEB", flags=Pattern.Flag.CASE_INSENSITIVE) String platform) {}
