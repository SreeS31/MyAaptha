package com.myaaptha.domain.ai;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class AiPreferenceServiceTest {
  private AiUserPreferenceRepository preferences;
  private AiActionEventRepository activity;
  private AiPreferenceService service;

  @BeforeEach
  void setUp() {
    preferences = mock(AiUserPreferenceRepository.class);
    activity = mock(AiActionEventRepository.class);
    when(preferences.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    service = new AiPreferenceService(preferences, activity);
  }

  @Test
  void defaultsSensitiveProcessingAndPersonalizationToOff() {
    when(preferences.findById(4L)).thenReturn(Optional.empty());
    var result = service.get(4L);
    assertThat(result.aiEnabled()).isTrue();
    assertThat(result.allowSensitiveData()).isFalse();
    assertThat(result.allowPersonalization()).isFalse();
    assertThat(result.activityRetentionDays()).isEqualTo(90);
  }

  @Test
  void disablingAiAlsoDisablesDependentPermissionsAndClearsZeroRetentionHistory() {
    when(preferences.findById(4L)).thenReturn(Optional.empty());
    var result = service.update(4L,
        new AiPreferenceService.UpdateAiPreferenceRequest(false, true, true, 0));
    assertThat(result.aiEnabled()).isFalse();
    assertThat(result.allowSensitiveData()).isFalse();
    assertThat(result.allowPersonalization()).isFalse();
    verify(activity).deleteByUserId(4L);
  }

  @Test
  void blocksSensitiveAiWithoutPersistentPermission() {
    when(preferences.findById(4L)).thenReturn(Optional.empty());
    assertThatThrownBy(() -> service.requireSensitiveDataAllowed(4L))
        .isInstanceOf(ResponseStatusException.class)
        .hasMessageContaining("sensitive-data");
  }

  @Test
  void purgesEventsOlderThanTheReducedRetentionWindow() {
    when(preferences.findById(4L)).thenReturn(Optional.empty());
    service.update(4L,
        new AiPreferenceService.UpdateAiPreferenceRequest(true, false, false, 30));
    verify(activity).deleteByUserIdAndCreatedAtBefore(eq(4L), any());
  }
}
