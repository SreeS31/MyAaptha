package com.myaaptha.domain.person.dto;

public class CreatePersonRequest {
  private String fullName;
  private String email;
  private String gender;

  public String getFullName() {
    return fullName;
  }

  public void setFullName(String fullName) {
    this.fullName = fullName;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }
  public String getGender() { return gender; }
  public void setGender(String gender) { this.gender = gender; }
}
