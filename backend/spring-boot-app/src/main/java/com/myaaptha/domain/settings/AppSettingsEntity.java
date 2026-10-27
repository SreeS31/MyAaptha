package com.myaaptha.domain.settings;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="app_settings")
public class AppSettingsEntity {
  @Id @Column(name="user_id") public Long userId;
  @Column(nullable=false) public boolean discoverable;
  @Column(name="share_interests",nullable=false) public boolean shareInterests;
  @Column(name="settings_json", nullable=false, columnDefinition="TEXT") public String settingsJson;
  @Column(name="updated_at", nullable=false) public Instant updatedAt = Instant.now();
}
