package com.myaaptha.domain.settings;
import static org.assertj.core.api.Assertions.*;
import java.time.Instant;
import org.junit.jupiter.api.Test;
class AppSettingsServiceTest {
  AppSettingsService.Settings quiet(String start,String end,String zone) {
    return new AppSettingsService.Settings(false,false,false,false,false,false,true,start,end,zone,false);
  }
  @Test void overnightQuietHoursRespectTimeZoneAndBoundaries() {
    var settings=quiet("22:00","07:00","Asia/Kolkata");
    assertThat(AppSettingsService.deliveryTime(settings,Instant.parse("2026-09-13T17:00:00Z"))).isEqualTo(Instant.parse("2026-09-14T01:30:00Z"));
    var end=Instant.parse("2026-09-14T01:30:00Z");assertThat(AppSettingsService.deliveryTime(settings,end)).isEqualTo(end);
  }
  @Test void daylightSavingTransitionUsesTheNextLocalEndTime() {
    assertThat(AppSettingsService.deliveryTime(quiet("22:00","07:00","America/New_York"),Instant.parse("2026-03-08T04:00:00Z"))).isEqualTo(Instant.parse("2026-03-08T11:00:00Z"));
  }
  @Test void disabledQuietHoursDoNotDelayDelivery() {
    var now=Instant.now();assertThat(AppSettingsService.deliveryTime(AppSettingsService.Settings.defaults(),now)).isEqualTo(now);
  }
}
