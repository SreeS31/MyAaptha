package com.myaaptha.domain.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AiActionLedgerServiceTest {
  private AiActionEventRepository repository;
  private AiActionLedgerService service;

  @BeforeEach
  void setUp() {
    repository = mock(AiActionEventRepository.class);
    when(repository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    service = new AiActionLedgerService(repository);
  }

  @Test
  void recordsPurposeAndConsentWithoutPromptContent() {
    AiActionEventEntity event = service.start(7L, "FAMILY_INSIGHTS", "L1",
        "Suggest relationship graph improvements", true, "APPROVED");

    assertThat(event.getUserId()).isEqualTo(7L);
    assertThat(event.getCapability()).isEqualTo("FAMILY_INSIGHTS");
    assertThat(event.getPurpose()).doesNotContain("prompt");
    assertThat(event.isConsentGranted()).isTrue();
    assertThat(event.getStatus()).isEqualTo("STARTED");
  }

  @Test
  void completesAndFailsWithBoundedMachineReadableState() {
    AiActionEventEntity success = service.start(7L, "SEARCH_RANKING", "L0",
        "Rank authorized search results", false, "NOT_REQUIRED");
    service.succeeded(success);
    assertThat(success.getStatus()).isEqualTo("SUCCEEDED");
    assertThat(success.getCompletedAt()).isNotNull();

    AiActionEventEntity failure = service.start(7L, "CONTACT_ORGANIZATION", "L1",
        "Suggest contact organization", true, "APPROVED");
    service.failed(failure, "AI_SERVICE_UNAVAILABLE");
    assertThat(failure.getStatus()).isEqualTo("FAILED");
    assertThat(failure.getFailureCode()).isEqualTo("AI_SERVICE_UNAVAILABLE");
  }

  @Test
  void readsOnlyTheAuthenticatedUsersRecentActivity() {
    when(repository.findTop50ByUserIdOrderByCreatedAtDesc(7L)).thenReturn(List.of());
    assertThat(service.recent(7L)).isEmpty();
    verify(repository).findTop50ByUserIdOrderByCreatedAtDesc(7L);
    verify(repository, never()).findTop50ByUserIdOrderByCreatedAtDesc(8L);
  }
}
