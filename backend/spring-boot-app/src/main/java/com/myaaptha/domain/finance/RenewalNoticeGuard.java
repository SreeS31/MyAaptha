package com.myaaptha.domain.finance;

import com.myaaptha.domain.notification.model.NotificationEntity;
import java.time.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Prevent delivery of a queued reminder after renewal, pause, archive or removal. */
@Component
public class RenewalNoticeGuard {
  private final JdbcTemplate db;
  public RenewalNoticeGuard(JdbcTemplate db){this.db=db;}
  public boolean enabled(NotificationEntity item){return enabled(item,Instant.now());}
  boolean enabled(NotificationEntity item,Instant now){
    var rows=db.queryForList("SELECT r.expires_on,r.timezone,n.reminder_days FROM finance_renewal_notices n JOIN finance_renewals r ON r.id=n.renewal_id AND r.cycle=n.cycle WHERE n.notification_id=? AND r.user_id=? AND r.reminders_enabled=TRUE AND r.archived=FALSE",item.getId(),item.getUserId());
    if(rows.isEmpty())return false;
    var row=rows.getFirst();LocalDate expires=((java.sql.Date)row.get("expires_on")).toLocalDate();
    LocalDate today=now.atZone(ZoneId.of((String)row.get("timezone"))).toLocalDate();
    return java.time.temporal.ChronoUnit.DAYS.between(today,expires)==((Number)row.get("reminder_days")).intValue();
  }
}
