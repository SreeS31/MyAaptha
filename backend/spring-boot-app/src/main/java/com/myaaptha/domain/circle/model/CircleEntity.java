package com.myaaptha.domain.circle.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.JoinColumn;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "circles")
public class CircleEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, unique = true)
  private String name;

  @Column(nullable = false)
  private String description;

  @Column(name = "owner_user_id")
  private Long ownerUserId;

  @Column(name = "posting_permission", nullable = false)
  private String postingPermission = "ALL_MEMBERS";

  @ElementCollection
  @CollectionTable(name = "circle_members", joinColumns = @JoinColumn(name = "circle_id"))
  @Column(name = "user_id")
  private Set<Long> memberUserIds = new HashSet<>();

  @ElementCollection
  @CollectionTable(name = "circle_admins", joinColumns = @JoinColumn(name = "circle_id"))
  @Column(name = "user_id")
  private Set<Long> adminUserIds = new HashSet<>();

  public Long getId() {
    return id;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getDescription() {
    return description;
  }

  public void setDescription(String description) {
    this.description = description;
  }

  public Long getOwnerUserId() { return ownerUserId; }
  public void setOwnerUserId(Long ownerUserId) { this.ownerUserId = ownerUserId; }
  public String getPostingPermission() { return postingPermission; }
  public void setPostingPermission(String postingPermission) { this.postingPermission = postingPermission; }
  public Set<Long> getMemberUserIds() { return memberUserIds; }
  public Set<Long> getAdminUserIds() { return adminUserIds; }
}
