package com.myaaptha.domain.relationship.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "relationships")
public class RelationshipEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String type;

  @Column(name = "owner_user_id")
  private Long ownerUserId;

  @Column(name = "related_user_id")
  private Long relatedUserId;

  @Column(name = "relative_to_user_id")
  private Long relativeToUserId;

  @Column(name = "contact_name")
  private String contactName;

  @Column(name = "contact_phone")
  private String contactPhone;

  @Column(name = "contact_email")
  private String contactEmail;

  @Column(name = "visibility_scope", nullable = false)
  private String visibilityScope = "FRIENDS";

  @Column(name = "visibility_company")
  private String visibilityCompany;

  @Column(name = "milestone_date")
  private String milestoneDate;

  @Column(name = "related_birth_date")
  private String relatedBirthDate;

  @Column(name = "related_death_date")
  private String relatedDeathDate;

  public Long getId() {
    return id;
  }

  public String getType() {
    return type;
  }

  public void setType(String type) {
    this.type = type;
  }

  public Long getOwnerUserId() { return ownerUserId; }
  public void setOwnerUserId(Long ownerUserId) { this.ownerUserId = ownerUserId; }
  public Long getRelatedUserId() { return relatedUserId; }
  public void setRelatedUserId(Long relatedUserId) { this.relatedUserId = relatedUserId; }
  public Long getRelativeToUserId() { return relativeToUserId; }
  public void setRelativeToUserId(Long relativeToUserId) { this.relativeToUserId = relativeToUserId; }
  public String getContactName() { return contactName; }
  public void setContactName(String contactName) { this.contactName = contactName; }
  public String getContactPhone() { return contactPhone; }
  public void setContactPhone(String contactPhone) { this.contactPhone = contactPhone; }
  public String getContactEmail() { return contactEmail; }
  public void setContactEmail(String contactEmail) { this.contactEmail = contactEmail; }
  public String getVisibilityScope() { return visibilityScope; }
  public void setVisibilityScope(String visibilityScope) { this.visibilityScope = visibilityScope; }
  public String getVisibilityCompany() { return visibilityCompany; }
  public void setVisibilityCompany(String visibilityCompany) { this.visibilityCompany = visibilityCompany; }
  public String getMilestoneDate() { return milestoneDate; }
  public void setMilestoneDate(String milestoneDate) { this.milestoneDate = milestoneDate; }
  public String getRelatedBirthDate() { return relatedBirthDate; }
  public void setRelatedBirthDate(String relatedBirthDate) { this.relatedBirthDate = relatedBirthDate; }
  public String getRelatedDeathDate() { return relatedDeathDate; }
  public void setRelatedDeathDate(String relatedDeathDate) { this.relatedDeathDate = relatedDeathDate; }
}
