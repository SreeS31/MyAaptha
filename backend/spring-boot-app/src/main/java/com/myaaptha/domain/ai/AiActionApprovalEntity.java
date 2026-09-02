package com.myaaptha.domain.ai;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ai_action_approvals")
public class AiActionApprovalEntity {
  @Id private UUID id;
  @Column(name = "user_id", nullable = false) private Long userId;
  @Column(nullable = false, length = 80) private String capability;
  @Column(name = "action_level", nullable = false, length = 2) private String actionLevel;
  @Column(nullable = false, length = 120) private String title;
  @Column(nullable = false, length = 500) private String summary;
  @Column(name = "resource_type", length = 80) private String resourceType;
  @Column(name = "resource_id", length = 120) private String resourceId;
  @Column(name = "action_fingerprint", nullable = false, length = 64) private String actionFingerprint;
  @Column(name = "pending_fingerprint", length = 64) private String pendingFingerprint;
  @Column(nullable = false, length = 20) private String status;
  @Column(name = "decision_reason", length = 240) private String decisionReason;
  @Column(name = "requested_at", nullable = false) private Instant requestedAt;
  @Column(name = "expires_at", nullable = false) private Instant expiresAt;
  @Column(name = "decided_at") private Instant decidedAt;
  @Version private long version;

  public UUID getId() { return id; }
  public void setId(UUID value) { id = value; }
  public Long getUserId() { return userId; }
  public void setUserId(Long value) { userId = value; }
  public String getCapability() { return capability; }
  public void setCapability(String value) { capability = value; }
  public String getActionLevel() { return actionLevel; }
  public void setActionLevel(String value) { actionLevel = value; }
  public String getTitle() { return title; }
  public void setTitle(String value) { title = value; }
  public String getSummary() { return summary; }
  public void setSummary(String value) { summary = value; }
  public String getResourceType() { return resourceType; }
  public void setResourceType(String value) { resourceType = value; }
  public String getResourceId() { return resourceId; }
  public void setResourceId(String value) { resourceId = value; }
  public String getActionFingerprint() { return actionFingerprint; }
  public void setActionFingerprint(String value) { actionFingerprint = value; }
  public String getPendingFingerprint() { return pendingFingerprint; }
  public void setPendingFingerprint(String value) { pendingFingerprint = value; }
  public String getStatus() { return status; }
  public void setStatus(String value) { status = value; }
  public String getDecisionReason() { return decisionReason; }
  public void setDecisionReason(String value) { decisionReason = value; }
  public Instant getRequestedAt() { return requestedAt; }
  public void setRequestedAt(Instant value) { requestedAt = value; }
  public Instant getExpiresAt() { return expiresAt; }
  public void setExpiresAt(Instant value) { expiresAt = value; }
  public Instant getDecidedAt() { return decidedAt; }
  public void setDecidedAt(Instant value) { decidedAt = value; }
}
