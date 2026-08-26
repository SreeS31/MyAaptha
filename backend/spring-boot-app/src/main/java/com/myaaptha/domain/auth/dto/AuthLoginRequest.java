package com.myaaptha.domain.auth.dto;

public class AuthLoginRequest {
  private String identifier;

  // Retained for compatibility with existing email-based clients.
  private String email;
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
