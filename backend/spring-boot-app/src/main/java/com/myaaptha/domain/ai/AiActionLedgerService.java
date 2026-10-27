package com.myaaptha.domain.ai;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiActionLedgerService {
  private final AiActionEventRepository events;

  public AiActionLedgerService(AiActionEventRepository events) { this.events = events; }

  @Transactional
  public AiActionEventEntity start(Long userId, String capability, String actionLevel,
      String purpose, boolean consentGranted, String approvalState) {
    AiActionEventEntity event = new AiActionEventEntity();
    event.setRequestId(UUID.randomUUID());
    event.setUserId(userId);
    event.setCapability(capability);
    event.setActionLevel(actionLevel);
    event.setPurpose(purpose);
    event.setConsentGranted(consentGranted);
    event.setApprovalState(approvalState);
    event.setStatus("STARTED");
    return events.save(event);
  }

  @Transactional
  public AiActionEventEntity startIfRetained(Long userId, String capability, String actionLevel,
      String purpose, boolean consentGranted, String approvalState, int retentionDays) {
    if (retentionDays == 0) return null;
    return start(userId, capability, actionLevel, purpose, consentGranted, approvalState);
  }

  @Transactional public void succeeded(AiActionEventEntity event) {
    if (event != null) finish(event, "SUCCEEDED", null);
  }
  @Transactional public void failed(AiActionEventEntity event, String code) {
    if (event != null) finish(event, "FAILED", code);
  }

  @Transactional(readOnly = true)
  public List<AiActionEventDto> recent(Long userId, int retentionDays) {
    if (retentionDays == 0) return List.of();
    Instant cutoff = Instant.now().minusSeconds(retentionDays * 86400L);
    return events.findTop50ByUserIdAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(userId, cutoff).stream()
        .map(AiActionEventDto::from).toList();
  }

  private void finish(AiActionEventEntity event, String status, String failureCode) {
    event.setStatus(status);
    event.setFailureCode(failureCode);
    event.setCompletedAt(Instant.now());
    events.save(event);
  }

  public record AiActionEventDto(UUID requestId, String capability, String actionLevel,
      String purpose, boolean consentGranted, String approvalState, String status,
      String failureCode, Instant createdAt, Instant completedAt) {
    static AiActionEventDto from(AiActionEventEntity event) {
      return new AiActionEventDto(event.getRequestId(), event.getCapability(),
          event.getActionLevel(), event.getPurpose(), event.isConsentGranted(),
          event.getApprovalState(), event.getStatus(), event.getFailureCode(),
          event.getCreatedAt(), event.getCompletedAt());
    }
  }
}
