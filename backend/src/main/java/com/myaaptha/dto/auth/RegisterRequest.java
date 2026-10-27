package com.myaaptha.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank
    private String fullName;

    @Email
    private String email;

    private String mobile;

    @NotBlank
    @Size(min = 8, max = 128)
    private String password;
}
