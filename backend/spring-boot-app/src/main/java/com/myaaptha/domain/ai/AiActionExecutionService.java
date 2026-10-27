package com.myaaptha.domain.ai;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AiActionExecutionService {
  private final AiActionApprovalRepository approvals;
  private final AiActionExecutionRepository executions;

  public AiActionExecutionService(AiActionApprovalRepository approvals,
      AiActionExecutionRepository executions) {
    this.approvals = approvals;
    this.executions = executions;
  }

  /** Internal agent tools call this before any side effect. It is intentionally not an HTTP endpoint. */
  @Transactional
  public AiActionExecutionDto claim(Long userId, UUID approvalId, String idempotencyKey) {
    String keyHash = hashRequired(idempotencyKey);
    AiActionApprovalEntity approval = approvals.lockByIdAndUserId(approvalId, userId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
            "AI approval request was not found"));
    var existing = executions.findByApprovalId(approvalId);
    if (existing.isPresent()) {
      if (!existing.get().getIdempotencyKeyHash().equals(keyHash)) {
        throw new ResponseStatusException(HttpStatus.CONFLICT,
            "This approval has already been claimed by another execution");
      }
      return AiActionExecutionDto.from(existing.get());
    }
    if (!"APPROVED".equals(approval.getStatus())) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN,
          "The AI action has not been approved");
    }
    Instant now = Instant.now();
    if (approval.getAuthorizationExpiresAt() == null
        || !approval.getAuthorizationExpiresAt().isAfter(now)) {
      throw new ResponseStatusException(HttpStatus.GONE,
          "The AI action authorization has expired");
    }
    AiActionExecutionEntity entity = new AiActionExecutionEntity();
    entity.setId(UUID.randomUUID());
    entity.setApprovalId(approvalId);
    entity.setUserId(userId);
    entity.setIdempotencyKeyHash(keyHash);
    entity.setStatus("RUNNING");
    entity.setStartedAt(now);
    return AiActionExecutionDto.from(executions.save(entity));
  }

  @Transactional
  public AiActionExecutionDto succeeded(Long userId, UUID executionId, String resultReference) {
    return finish(userId, executionId, "SUCCEEDED", null, resultReference);
  }

  @Transactional
  public AiActionExecutionDto failed(Long userId, UUID executionId, String failureCode) {
    return finish(userId, executionId, "FAILED", requiredCode(failureCode), null);
  }

  @Transactional(readOnly = true)
  public List<AiActionExecutionDto> recent(Long userId) {
    return executions.findTop100ByUserIdOrderByStartedAtDesc(userId).stream()
        .map(AiActionExecutionDto::from).toList();
  }

  private AiActionExecutionDto finish(Long userId, UUID executionId, String status,
      String failureCode, String resultReference) {
    AiActionExecutionEntity entity = executions.findByIdAndUserId(executionId, userId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
            "AI action execution was not found"));
    if (!"RUNNING".equals(entity.getStatus())) {
      throw new ResponseStatusException(HttpStatus.CONFLICT,
          "This AI action execution is already final");
    }
    entity.setStatus(status);
    entity.setFailureCode(failureCode);
    entity.setResultReference(limitNullable(resultReference, 240));
    entity.setCompletedAt(Instant.now());
    return AiActionExecutionDto.from(executions.save(entity));
  }

  private String hashRequired(String value) {
    if (value == null || value.isBlank() || value.length() > 240) {
      throw new IllegalArgumentException("A bounded idempotency key is required");
    }
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
          .digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Unable to hash the idempotency key", exception);
    }
  }

  private String requiredCode(String value) {
    if (value == null || !value.matches("[A-Z0-9_]{1,80}")) {
      throw new IllegalArgumentException("A valid failure code is required");
    }
    return value;
  }

  private String limitNullable(String value, int max) {
    if (value == null || value.isBlank()) return null;
    String trimmed = value.trim();
    return trimmed.substring(0, Math.min(trimmed.length(), max));
  }

  public record AiActionExecutionDto(UUID id, UUID approvalId, String status,
      String failureCode, String resultReference, Instant startedAt, Instant completedAt) {
    static AiActionExecutionDto from(AiActionExecutionEntity entity) {
      return new AiActionExecutionDto(entity.getId(), entity.getApprovalId(), entity.getStatus(),
          entity.getFailureCode(), entity.getResultReference(), entity.getStartedAt(),
          entity.getCompletedAt());
    }
  }
}
