package com.myaaptha.domain.ai;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class AiActionApprovalServiceTest {
  private AiActionApprovalRepository repository;
  private AiActionApprovalService service;

  @BeforeEach
  void setUp() {
    repository = mock(AiActionApprovalRepository.class);
    when(repository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    service = new AiActionApprovalService(repository);
  }

  @Test
  void acceptsOnlyReversibleOrSensitiveActionLevels() {
    assertThatThrownBy(() -> service.request(1L, "DELETE_ACCOUNT", "L4", "Delete account",
        "Permanently delete this account", "ACCOUNT", "1", Duration.ofMinutes(10)))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("L2 and L3");
    verify(repository, never()).save(any());
  }

  @Test
  void deduplicatesPendingRequestsByActionFingerprint() {
    when(repository.findByUserIdAndPendingFingerprint(eq(1L), anyString()))
        .thenReturn(Optional.empty());
    var created = service.request(1L, "SEND_MESSAGE", "L3", "Send message",
        "Send the prepared birthday message", "USER", "9", Duration.ofMinutes(15));
    assertThat(created.status()).isEqualTo("PENDING");
    assertThat(created.expiresAt()).isAfter(created.requestedAt());
    verify(repository).save(any());
  }

  @Test
  void cannotDecideAnotherUsersApproval() {
    UUID id = UUID.randomUUID();
    when(repository.findByIdAndUserId(id, 2L)).thenReturn(Optional.empty());
    assertThatThrownBy(() -> service.decide(2L, id, "APPROVED", null))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("not found");
  }

  @Test
  void decisionIsFinalAndDoesNotExecuteTheAction() {
    UUID id = UUID.randomUUID();
    AiActionApprovalEntity entity = pending(id, 1L, Instant.now().plusSeconds(300));
    when(repository.findByIdAndUserId(id, 1L)).thenReturn(Optional.of(entity));
    var result = service.decide(1L, id, "APPROVED", "I reviewed the message");
    assertThat(result.status()).isEqualTo("APPROVED");
    assertThat(result.decidedAt()).isNotNull();
    assertThat(result.decisionReason()).isEqualTo("I reviewed the message");
    assertThat(entity.getPendingFingerprint()).isNull();
  }

  @Test
  void expiredApprovalCannotBeRevived() {
    UUID id = UUID.randomUUID();
    AiActionApprovalEntity entity = pending(id, 1L, Instant.now().minusSeconds(1));
    when(repository.findByIdAndUserId(id, 1L)).thenReturn(Optional.of(entity));
    assertThatThrownBy(() -> service.decide(1L, id, "APPROVED", null))
        .isInstanceOf(ResponseStatusException.class).hasMessageContaining("expired");
    assertThat(entity.getStatus()).isEqualTo("EXPIRED");
  }

  @Test
  void listingExpiresOnlyPendingItems() {
    AiActionApprovalEntity expired = pending(UUID.randomUUID(), 1L, Instant.now().minusSeconds(1));
    AiActionApprovalEntity approved = pending(UUID.randomUUID(), 1L, Instant.now().minusSeconds(1));
    approved.setStatus("APPROVED");
    when(repository.findTop100ByUserIdOrderByRequestedAtDesc(1L))
        .thenReturn(List.of(expired, approved));
    var result = service.recent(1L);
    assertThat(result).extracting(AiActionApprovalService.AiActionApprovalDto::status)
        .containsExactly("EXPIRED", "APPROVED");
    verify(repository).saveAll(List.of(expired));
  }

  private AiActionApprovalEntity pending(UUID id, Long userId, Instant expiresAt) {
    AiActionApprovalEntity entity = new AiActionApprovalEntity();
    entity.setId(id);
    entity.setUserId(userId);
    entity.setCapability("SEND_MESSAGE");
    entity.setActionLevel("L3");
    entity.setTitle("Send message");
    entity.setSummary("Send the prepared message");
    entity.setActionFingerprint("a".repeat(64));
    entity.setPendingFingerprint("a".repeat(64));
    entity.setStatus("PENDING");
    entity.setRequestedAt(Instant.now().minusSeconds(60));
    entity.setExpiresAt(expiresAt);
    return entity;
  }
}
