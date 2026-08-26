package com.myaaptha.domain.user.dto;

public class UserDto {
  private Long id;
  private String username;
  private String email;
  private String phoneNumber;
  private String role;
  private String firstName;
  private String surname;
  private String location;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getUsername() {
    return username;
  }

  public void setUsername(String username) {
    this.username = username;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getPhoneNumber() {
    return phoneNumber;
  }

  public void setPhoneNumber(String phoneNumber) {
    this.phoneNumber = phoneNumber;
  }

  public String getRole() {
    return role;
  }

  public void setRole(String role) {
    this.role = role;
  }

  public String getFirstName() { return firstName; }
  public void setFirstName(String firstName) { this.firstName = firstName; }
  public String getSurname() { return surname; }
  public void setSurname(String surname) { this.surname = surname; }
  public String getLocation() { return location; }
  public void setLocation(String location) { this.location = location; }
}
