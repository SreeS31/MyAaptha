package com.myaaptha.domain.ai;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "ai_user_preferences")
public class AiUserPreferenceEntity {
  @Id @Column(name = "user_id") private Long userId;
  @Column(name = "ai_enabled", nullable = false) private boolean aiEnabled = true;
  @Column(name = "allow_sensitive_data", nullable = false) private boolean allowSensitiveData;
  @Column(name = "allow_personalization", nullable = false) private boolean allowPersonalization;
  @Column(name = "activity_retention_days", nullable = false) private int activityRetentionDays = 90;
  @Column(name = "updated_at", nullable = false) private Instant updatedAt = Instant.now();

  public Long getUserId() { return userId; }
  public void setUserId(Long value) { userId = value; }
  public boolean isAiEnabled() { return aiEnabled; }
  public void setAiEnabled(boolean value) { aiEnabled = value; }
  public boolean isAllowSensitiveData() { return allowSensitiveData; }
  public void setAllowSensitiveData(boolean value) { allowSensitiveData = value; }
  public boolean isAllowPersonalization() { return allowPersonalization; }
  public void setAllowPersonalization(boolean value) { allowPersonalization = value; }
  public int getActivityRetentionDays() { return activityRetentionDays; }
  public void setActivityRetentionDays(int value) { activityRetentionDays = value; }
  public Instant getUpdatedAt() { return updatedAt; }
  public void setUpdatedAt(Instant value) { updatedAt = value; }
}
