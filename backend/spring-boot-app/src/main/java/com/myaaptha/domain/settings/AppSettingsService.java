package com.myaaptha.domain.settings;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AppSettingsService {
  private final AppSettingsRepository repository;
  private final ObjectMapper mapper;
  public AppSettingsService(AppSettingsRepository repository, ObjectMapper mapper) { this.repository=repository;this.mapper=mapper; }
  public record Settings(
      @NotNull Boolean discoverable, @NotNull Boolean shareConnections, @NotNull Boolean shareInterests,
      @NotNull Boolean intelligentSearch, @NotNull Boolean compactLayout, @NotNull Boolean reducedMotion,
      @NotNull Boolean quietHoursEnabled,
      @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]") String quietStart,
      @NotNull @Pattern(regexp="(?:[01][0-9]|2[0-3]):[0-5][0-9]") String quietEnd,
      @NotNull @Size(min=1,max=80) String timeZone, @NotNull Boolean notificationPreviews) {
    public static Settings defaults() { return new Settings(false,false,false,true,false,false,false,"22:00","07:00","UTC",false); }
  }
  @Transactional(readOnly=true)
  public Settings get(Long userId) { return repository.findById(userId).map(this::decode).orElseGet(Settings::defaults); }
  @Transactional(readOnly=true)
  public Map<Long,Settings> getAll(Collection<Long> ids) {
    var result = new HashMap<Long,Settings>();
    repository.findAllById(ids).forEach(row -> result.put(row.userId,decode(row)));
    return result;
  }
  @Transactional
  public Settings update(Long userId, Settings values) {
    try { ZoneId.of(values.timeZone()); LocalTime.parse(values.quietStart()); LocalTime.parse(values.quietEnd()); }
    catch (DateTimeException error) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a valid time zone and quiet hours"); }
    if(values.quietHoursEnabled() && values.quietStart().equals(values.quietEnd()))
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Quiet hours must have different start and end times");
    var row=repository.findById(userId).orElseGet(AppSettingsEntity::new);
    row.userId=userId;row.discoverable=values.discoverable();row.shareInterests=values.shareInterests();row.updatedAt=Instant.now();
    try { row.settingsJson=mapper.writeValueAsString(values); }
    catch (Exception error) { throw new IllegalStateException("Settings could not be saved"); }
    repository.save(row);return values;
  }
  private Settings decode(AppSettingsEntity row) {
    try { return mapper.readValue(row.settingsJson,Settings.class); }
    catch (Exception error) { throw new IllegalStateException("Settings could not be loaded"); }
  }
  public static Instant deliveryTime(Settings settings, Instant now) {
    if(!settings.quietHoursEnabled()) return now;
    var local=now.atZone(ZoneId.of(settings.timeZone()));
    var start=LocalTime.parse(settings.quietStart());var end=LocalTime.parse(settings.quietEnd());var time=local.toLocalTime();
    boolean overnight=start.isAfter(end);
    boolean quiet=overnight ? !time.isBefore(start)||time.isBefore(end) : !time.isBefore(start)&&time.isBefore(end);
    if(!quiet)return now;
    var endDate=local.toLocalDate().plusDays(overnight&&!time.isBefore(start)?1:0);
    return endDate.atTime(end).atZone(local.getZone()).toInstant();
  }
}
