package com.myaaptha.domain.ai;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AiPreferenceService {
  private final AiUserPreferenceRepository preferences;
  private final AiActionEventRepository activity;

  public AiPreferenceService(AiUserPreferenceRepository preferences,
      AiActionEventRepository activity) {
    this.preferences = preferences;
    this.activity = activity;
  }

  @Transactional(readOnly = true)
  public AiPreferenceDto get(Long userId) {
    return preferences.findById(userId).map(AiPreferenceDto::from)
        .orElseGet(() -> AiPreferenceDto.defaults(userId));
  }

  @Transactional
  public AiPreferenceDto update(Long userId, @Valid UpdateAiPreferenceRequest request) {
    AiUserPreferenceEntity entity = preferences.findById(userId).orElseGet(() -> {
      AiUserPreferenceEntity created = new AiUserPreferenceEntity();
      created.setUserId(userId);
      return created;
    });
    entity.setAiEnabled(request.aiEnabled());
    entity.setAllowSensitiveData(request.aiEnabled() && request.allowSensitiveData());
    entity.setAllowPersonalization(request.aiEnabled() && request.allowPersonalization());
    entity.setActivityRetentionDays(request.activityRetentionDays());
    entity.setUpdatedAt(Instant.now());
    if (request.activityRetentionDays() == 0) {
      activity.deleteByUserId(userId);
    } else {
      activity.deleteByUserIdAndCreatedAtBefore(userId,
          Instant.now().minusSeconds(request.activityRetentionDays() * 86400L));
    }
    return AiPreferenceDto.from(preferences.save(entity));
  }

  @Transactional(readOnly = true)
  public void requireEnabled(Long userId) {
    if (!get(userId).aiEnabled()) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN,
          "AI assistance is disabled in your account settings");
    }
  }

  @Transactional(readOnly = true)
  public void requireSensitiveDataAllowed(Long userId) {
    AiPreferenceDto preference = get(userId);
    if (!preference.aiEnabled() || !preference.allowSensitiveData()) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN,
          "Enable sensitive-data AI processing in AI controls before using this feature");
    }
  }

  public record UpdateAiPreferenceRequest(@NotNull Boolean aiEnabled,
      @NotNull Boolean allowSensitiveData, @NotNull Boolean allowPersonalization,
      @NotNull @Min(0) @Max(365) Integer activityRetentionDays) {}

  public record AiPreferenceDto(Long userId, boolean aiEnabled, boolean allowSensitiveData,
      boolean allowPersonalization, int activityRetentionDays, Instant updatedAt) {
    static AiPreferenceDto defaults(Long userId) {
      return new AiPreferenceDto(userId, true, false, false, 90, null);
    }

    static AiPreferenceDto from(AiUserPreferenceEntity entity) {
      return new AiPreferenceDto(entity.getUserId(), entity.isAiEnabled(),
          entity.isAllowSensitiveData(), entity.isAllowPersonalization(),
          entity.getActivityRetentionDays(), entity.getUpdatedAt());
    }
  }
}
