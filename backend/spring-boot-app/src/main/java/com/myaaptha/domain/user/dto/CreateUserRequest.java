package com.myaaptha.domain.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public class CreateUserRequest {
  @NotBlank @Size(min=3,max=64) @Pattern(regexp="^[A-Za-z0-9._-]+$",message="must use letters, numbers, dots, underscores, or hyphens")
  private String username;
  @Email @Size(max=254)
  private String email;
  @NotBlank @Pattern(regexp="^\\+?[0-9 ()-]{7,32}$",message="must be a valid phone number")
  private String phoneNumber;
  @NotBlank @Size(min=8,max=128)
  private String password;
  @Size(max=100)
  private String firstName;
  @Size(max=100)
  private String surname;
  @Size(max=255)
  private String location;

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

  public String getPassword() {
    return password;
  }

  public void setPassword(String password) {
    this.password = password;
  }

  public String getFirstName() { return firstName; }
  public void setFirstName(String firstName) { this.firstName = firstName; }
  public String getSurname() { return surname; }
  public void setSurname(String surname) { this.surname = surname; }
  public String getLocation() { return location; }
  public void setLocation(String location) { this.location = location; }
}
