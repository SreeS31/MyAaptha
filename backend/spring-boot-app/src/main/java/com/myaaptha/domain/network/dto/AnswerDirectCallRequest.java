package com.myaaptha.domain.network.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record AnswerDirectCallRequest(@NotBlank @Size(max=131072) String answerSdp) {}
