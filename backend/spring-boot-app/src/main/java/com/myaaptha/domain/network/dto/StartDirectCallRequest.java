package com.myaaptha.domain.network.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
public record StartDirectCallRequest(@NotNull @Positive Long recipientId,
    @NotBlank @Pattern(regexp="AUDIO|VIDEO") String callType,
    @NotBlank @Size(max=131072) String offerSdp) {}
