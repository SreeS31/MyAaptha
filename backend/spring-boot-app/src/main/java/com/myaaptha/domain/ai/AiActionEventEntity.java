package com.myaaptha.domain.ai;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ai_action_events")
public class AiActionEventEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  @Column(name = "request_id", nullable = false, unique = true) private UUID requestId;
  @Column(name = "user_id", nullable = false) private Long userId;
  @Column(nullable = false, length = 80) private String capability;
  @Column(name = "action_level", nullable = false, length = 2) private String actionLevel;
  @Column(nullable = false, length = 240) private String purpose;
  @Column(name = "consent_granted", nullable = false) private boolean consentGranted;
  @Column(name = "approval_state", nullable = false, length = 20) private String approvalState;
  @Column(nullable = false, length = 20) private String status;
  @Column(name = "failure_code", length = 80) private String failureCode;
  @Column(name = "created_at", nullable = false) private Instant createdAt;
  @Column(name = "completed_at") private Instant completedAt;

  @PrePersist void initialize() {
    if (requestId == null) requestId = UUID.randomUUID();
    if (createdAt == null) createdAt = Instant.now();
  }

  public UUID getRequestId() { return requestId; }
  public void setRequestId(UUID value) { requestId = value; }
  public Long getUserId() { return userId; }
  public void setUserId(Long value) { userId = value; }
  public String getCapability() { return capability; }
  public void setCapability(String value) { capability = value; }
  public String getActionLevel() { return actionLevel; }
  public void setActionLevel(String value) { actionLevel = value; }
  public String getPurpose() { return purpose; }
  public void setPurpose(String value) { purpose = value; }
  public boolean isConsentGranted() { return consentGranted; }
  public void setConsentGranted(boolean value) { consentGranted = value; }
  public String getApprovalState() { return approvalState; }
  public void setApprovalState(String value) { approvalState = value; }
  public String getStatus() { return status; }
  public void setStatus(String value) { status = value; }
  public String getFailureCode() { return failureCode; }
  public void setFailureCode(String value) { failureCode = value; }
  public Instant getCreatedAt() { return createdAt; }
  public Instant getCompletedAt() { return completedAt; }
  public void setCompletedAt(Instant value) { completedAt = value; }
}
