package com.myaaptha.domain.user.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class UserEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, unique = true)
  private String username;

  @Column(unique = true)
  private String email;

  @Column(name = "phone_number", unique = true)
  private String phoneNumber;

  @Column(nullable = false)
  private String role = "USER";

  @Column(nullable = false)
  private String passwordHash;

  private String firstName;
  private String surname;
  private String location;

  @Column(name = "account_status", nullable = false)
  private String accountStatus = "ACTIVE";

  @Column(name = "identity_type", nullable = false)
  private String identityType = "ACCOUNT";

  @Column(name = "managed_category")
  private String managedCategory;

  @Column(name = "guardian_user_id")
  private Long guardianUserId;

  @Column(name = "claim_status", nullable = false)
  private String claimStatus = "NONE";

  @Column(name = "managed_date_of_birth")
  private String managedDateOfBirth;

  @Column(name = "managed_date_of_death")
  private String managedDateOfDeath;

  @Column(name = "managed_notes", length = 2000)
  private String managedNotes;

  public Long getId() {
    return id;
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

  public String getPasswordHash() {
    return passwordHash;
  }

  public void setPasswordHash(String passwordHash) {
    this.passwordHash = passwordHash;
  }

  public String getFirstName() { return firstName; }
  public void setFirstName(String firstName) { this.firstName = firstName; }
  public String getSurname() { return surname; }
  public void setSurname(String surname) { this.surname = surname; }
  public String getLocation() { return location; }
  public void setLocation(String location) { this.location = location; }
  public String getAccountStatus() { return accountStatus; }
  public void setAccountStatus(String accountStatus) { this.accountStatus = accountStatus; }
  public String getIdentityType() { return identityType; }
  public void setIdentityType(String identityType) { this.identityType = identityType; }
  public String getManagedCategory() { return managedCategory; }
  public void setManagedCategory(String managedCategory) { this.managedCategory = managedCategory; }
  public Long getGuardianUserId() { return guardianUserId; }
  public void setGuardianUserId(Long guardianUserId) { this.guardianUserId = guardianUserId; }
  public String getClaimStatus() { return claimStatus; }
  public void setClaimStatus(String claimStatus) { this.claimStatus = claimStatus; }
  public String getManagedDateOfBirth() { return managedDateOfBirth; }
  public void setManagedDateOfBirth(String managedDateOfBirth) { this.managedDateOfBirth = managedDateOfBirth; }
  public String getManagedDateOfDeath() { return managedDateOfDeath; }
  public void setManagedDateOfDeath(String managedDateOfDeath) { this.managedDateOfDeath = managedDateOfDeath; }
  public String getManagedNotes() { return managedNotes; }
  public void setManagedNotes(String managedNotes) { this.managedNotes = managedNotes; }
}
