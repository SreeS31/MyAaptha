package com.myaaptha.domain.ai;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ai_action_executions")
public class AiActionExecutionEntity {
  @Id private UUID id;
  @Column(name = "approval_id", nullable = false, unique = true) private UUID approvalId;
  @Column(name = "user_id", nullable = false) private Long userId;
  @Column(name = "idempotency_key_hash", nullable = false, length = 64) private String idempotencyKeyHash;
  @Column(nullable = false, length = 20) private String status;
  @Column(name = "failure_code", length = 80) private String failureCode;
  @Column(name = "result_reference", length = 240) private String resultReference;
  @Column(name = "started_at", nullable = false) private Instant startedAt;
  @Column(name = "completed_at") private Instant completedAt;
  @Version private long version;

  public UUID getId() { return id; }
  public void setId(UUID value) { id = value; }
  public UUID getApprovalId() { return approvalId; }
  public void setApprovalId(UUID value) { approvalId = value; }
  public Long getUserId() { return userId; }
  public void setUserId(Long value) { userId = value; }
  public String getIdempotencyKeyHash() { return idempotencyKeyHash; }
  public void setIdempotencyKeyHash(String value) { idempotencyKeyHash = value; }
  public String getStatus() { return status; }
  public void setStatus(String value) { status = value; }
  public String getFailureCode() { return failureCode; }
  public void setFailureCode(String value) { failureCode = value; }
  public String getResultReference() { return resultReference; }
  public void setResultReference(String value) { resultReference = value; }
  public Instant getStartedAt() { return startedAt; }
  public void setStartedAt(Instant value) { startedAt = value; }
  public Instant getCompletedAt() { return completedAt; }
  public void setCompletedAt(Instant value) { completedAt = value; }
}
