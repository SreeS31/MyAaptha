package com.myaaptha.domain.person.dto;

public class PersonDto {
  private Long id;
  private String fullName;
  private String email;
  private String gender;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

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
