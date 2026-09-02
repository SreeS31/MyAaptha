package com.myaaptha.domain.ai;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AiActionApprovalService {
  private static final Set<String> ALLOWED_LEVELS = Set.of("L2", "L3");
  private final AiActionApprovalRepository approvals;

  public AiActionApprovalService(AiActionApprovalRepository approvals) {
    this.approvals = approvals;
  }

  @Transactional
  public AiActionApprovalDto request(Long userId, String capability, String actionLevel,
      String title, String summary, String resourceType, String resourceId, Duration validity) {
    if (!ALLOWED_LEVELS.contains(actionLevel)) {
      throw new IllegalArgumentException("Only L2 and L3 actions may request approval");
    }
    if (validity.isNegative() || validity.isZero() || validity.compareTo(Duration.ofDays(7)) > 0) {
      throw new IllegalArgumentException("Approval validity must be between 1 second and 7 days");
    }
    String fingerprint = fingerprint(userId, capability, resourceType, resourceId, summary);
    return approvals.findByUserIdAndPendingFingerprint(userId, fingerprint)
        .map(AiActionApprovalDto::from).orElseGet(() -> {
          Instant now = Instant.now();
          AiActionApprovalEntity entity = new AiActionApprovalEntity();
          entity.setId(UUID.randomUUID());
          entity.setUserId(userId);
          entity.setCapability(limit(capability, 80));
          entity.setActionLevel(actionLevel);
          entity.setTitle(limit(title, 120));
          entity.setSummary(limit(summary, 500));
          entity.setResourceType(limitNullable(resourceType, 80));
          entity.setResourceId(limitNullable(resourceId, 120));
          entity.setActionFingerprint(fingerprint);
          entity.setPendingFingerprint(fingerprint);
          entity.setStatus("PENDING");
          entity.setRequestedAt(now);
          entity.setExpiresAt(now.plus(validity));
          return AiActionApprovalDto.from(approvals.save(entity));
        });
  }

  @Transactional
  public List<AiActionApprovalDto> recent(Long userId) {
    Instant now = Instant.now();
    List<AiActionApprovalEntity> entities = approvals.findTop100ByUserIdOrderByRequestedAtDesc(userId);
    List<AiActionApprovalEntity> expired = entities.stream()
        .filter(item -> "PENDING".equals(item.getStatus()) && !item.getExpiresAt().isAfter(now))
        .toList();
    expired.forEach(item -> {
          item.setStatus("EXPIRED");
          item.setPendingFingerprint(null);
          item.setDecidedAt(now);
        });
    if (!expired.isEmpty()) approvals.saveAll(expired);
    return entities.stream().map(AiActionApprovalDto::from).toList();
  }

  @Transactional
  public AiActionApprovalDto decide(Long userId, UUID approvalId, String decision, String reason) {
    if (decision == null || !Set.of("APPROVED", "REJECTED").contains(decision)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
          "Decision must be APPROVED or REJECTED");
    }
    AiActionApprovalEntity entity = approvals.findByIdAndUserId(approvalId, userId)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
            "AI approval request was not found"));
    if (!"PENDING".equals(entity.getStatus())) {
      throw new ResponseStatusException(HttpStatus.CONFLICT,
          "This AI approval request has already been decided");
    }
    Instant now = Instant.now();
    if (!entity.getExpiresAt().isAfter(now)) {
      entity.setStatus("EXPIRED");
      entity.setPendingFingerprint(null);
      entity.setDecidedAt(now);
      approvals.save(entity);
      throw new ResponseStatusException(HttpStatus.GONE,
          "This AI approval request has expired");
    }
    entity.setStatus(decision);
    entity.setPendingFingerprint(null);
    entity.setDecisionReason(limitNullable(reason, 240));
    entity.setDecidedAt(now);
    return AiActionApprovalDto.from(approvals.save(entity));
  }

  private String fingerprint(Long userId, String capability, String resourceType,
      String resourceId, String summary) {
    try {
      String value = userId + "|" + capability + "|" + resourceType + "|" + resourceId + "|" + summary;
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
          .digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Unable to fingerprint AI approval", exception);
    }
  }

  private String limit(String value, int max) {
    if (value == null || value.isBlank()) throw new IllegalArgumentException("Approval text is required");
    String trimmed = value.trim();
    return trimmed.substring(0, Math.min(trimmed.length(), max));
  }

  private String limitNullable(String value, int max) {
    return value == null || value.isBlank() ? null : limit(value, max);
  }

  public record AiActionApprovalDto(UUID id, String capability, String actionLevel,
      String title, String summary, String resourceType, String resourceId, String status,
      String decisionReason, Instant requestedAt, Instant expiresAt, Instant decidedAt) {
    static AiActionApprovalDto from(AiActionApprovalEntity entity) {
      return new AiActionApprovalDto(entity.getId(), entity.getCapability(), entity.getActionLevel(),
          entity.getTitle(), entity.getSummary(), entity.getResourceType(), entity.getResourceId(),
          entity.getStatus(), entity.getDecisionReason(), entity.getRequestedAt(),
          entity.getExpiresAt(), entity.getDecidedAt());
    }
  }
}
