package com.myaaptha.domain.ai;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class AiActionExecutionServiceTest {
  private AiActionApprovalRepository approvals;
  private AiActionExecutionRepository executions;
  private AiActionExecutionService service;

  @BeforeEach
  void setUp() {
    approvals = mock(AiActionApprovalRepository.class);
    executions = mock(AiActionExecutionRepository.class);
    when(executions.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    service = new AiActionExecutionService(approvals, executions);
  }

  @Test
  void rejectsUnapprovedAndExpiredActions() {
    UUID pendingId = UUID.randomUUID();
    when(approvals.lockByIdAndUserId(pendingId, 1L))
        .thenReturn(Optional.of(approval(pendingId, "PENDING", Instant.now().plusSeconds(60))));
    assertThatThrownBy(() -> service.claim(1L, pendingId, "request-1"))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("not been approved");

    UUID expiredId = UUID.randomUUID();
    when(approvals.lockByIdAndUserId(expiredId, 1L))
        .thenReturn(Optional.of(approval(expiredId, "APPROVED", Instant.now().minusSeconds(1))));
    assertThatThrownBy(() -> service.claim(1L, expiredId, "request-2"))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("expired");
    verify(executions, never()).save(any());
  }

  @Test
  void claimIsIdempotentForTheSameKey() {
    UUID approvalId = UUID.randomUUID();
    when(approvals.lockByIdAndUserId(approvalId, 1L))
        .thenReturn(Optional.of(approval(approvalId, "APPROVED", Instant.now().plusSeconds(60))));
    when(executions.findByApprovalId(approvalId)).thenReturn(Optional.empty());
    var first = service.claim(1L, approvalId, "stable-request-key");
    assertThat(first.status()).isEqualTo("RUNNING");

    var stored = execution(first.id(), approvalId, 1L, "RUNNING");
    stored.setIdempotencyKeyHash(hash("stable-request-key"));
    when(executions.findByApprovalId(approvalId)).thenReturn(Optional.of(stored));
    var replay = service.claim(1L, approvalId, "stable-request-key");
    assertThat(replay.id()).isEqualTo(first.id());
    verify(executions, times(1)).save(any());
  }

  @Test
  void differentKeyCannotReplayAnApproval() {
    UUID approvalId = UUID.randomUUID();
    when(approvals.lockByIdAndUserId(approvalId, 1L))
        .thenReturn(Optional.of(approval(approvalId, "APPROVED", Instant.now().plusSeconds(60))));
    AiActionExecutionEntity stored = execution(UUID.randomUUID(), approvalId, 1L, "RUNNING");
    stored.setIdempotencyKeyHash(hash("original-key"));
    when(executions.findByApprovalId(approvalId)).thenReturn(Optional.of(stored));
    assertThatThrownBy(() -> service.claim(1L, approvalId, "different-key"))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("already been claimed");
  }

  @Test
  void onlyOwnerCanFinishAndFinalStateCannotChange() {
    UUID executionId = UUID.randomUUID();
    when(executions.findByIdAndUserId(executionId, 2L)).thenReturn(Optional.empty());
    assertThatThrownBy(() -> service.succeeded(2L, executionId, "message:9"))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("not found");

    AiActionExecutionEntity finished = execution(executionId, UUID.randomUUID(), 1L, "SUCCEEDED");
    when(executions.findByIdAndUserId(executionId, 1L)).thenReturn(Optional.of(finished));
    assertThatThrownBy(() -> service.failed(1L, executionId, "TOOL_FAILED"))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("already final");
  }

  private AiActionApprovalEntity approval(UUID id, String status, Instant authorizationExpiry) {
    AiActionApprovalEntity entity = new AiActionApprovalEntity();
    entity.setId(id);
    entity.setUserId(1L);
    entity.setStatus(status);
    entity.setAuthorizationExpiresAt(authorizationExpiry);
    return entity;
  }

  private AiActionExecutionEntity execution(UUID id, UUID approvalId, Long userId, String status) {
    AiActionExecutionEntity entity = new AiActionExecutionEntity();
    entity.setId(id);
    entity.setApprovalId(approvalId);
    entity.setUserId(userId);
    entity.setStatus(status);
    entity.setStartedAt(Instant.now());
    return entity;
  }

  private String hash(String value) {
    try {
      return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256")
          .digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new AssertionError(exception);
    }
  }
}
