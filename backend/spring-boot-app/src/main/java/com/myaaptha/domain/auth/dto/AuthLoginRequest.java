package com.myaaptha.domain.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class AuthLoginRequest {
  @Size(max=254)
  private String identifier;

  // Retained for compatibility with existing email-based clients.
  @Email @Size(max=254)
  private String email;
  @NotBlank @Size(min=6,max=128)
  private String password;

  public String getIdentifier() {
    return identifier;
  }

  public void setIdentifier(String identifier) {
    this.identifier = identifier;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getPassword() {
    return password;
  }

  public void setPassword(String password) {
    this.password = password;
  }
}
