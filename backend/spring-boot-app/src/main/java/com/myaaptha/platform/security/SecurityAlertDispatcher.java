package com.myaaptha.platform.security;

import com.myaaptha.domain.notification.WebhookNotificationProvider;
import com.myaaptha.domain.notification.model.*;
import com.myaaptha.platform.state.ScheduledJobLock;
import java.sql.Timestamp;
import java.time.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SecurityAlertDispatcher {
 private final JdbcTemplate jdbc;private final ScheduledJobLock lock;private final WebhookNotificationProvider provider;private final String email;
 public SecurityAlertDispatcher(JdbcTemplate jdbc,ScheduledJobLock lock,WebhookNotificationProvider provider,@Value("${MYAAPTHA_SECURITY_ADMIN_EMAIL:}")String email){this.jdbc=jdbc;this.lock=lock;this.provider=provider;this.email=email.trim();}
 public boolean configured(){return email.matches("[^ @]+@[^ @]+[.][^ @]+")&&email.chars().noneMatch(Character::isWhitespace)&&provider.configured()&&"EMAIL".equals(provider.channel());}
 @Scheduled(fixedDelayString="${myaaptha.security.alert-delay-ms:60000}") @Transactional
 public void dispatch(){
  if(!configured()||!lock.acquire("security-alerts"))return;
  var rows=jdbc.queryForList("SELECT id,category,summary FROM security_incidents WHERE email_status='PENDING' AND email_next_attempt<=? ORDER BY id LIMIT 5",Timestamp.from(Instant.now()));
  for(var row:rows){long id=((Number)row.get("id")).longValue();try{
   var notification=new NotificationEntity();notification.setTitle("MyAaptha security report #"+id);notification.setBody(row.get("category")+": "+row.get("summary")+". Sign in as an administrator to review the report.");notification.setActionUrl("/security-reports");
   var delivery=new NotificationDeliveryEntity();delivery.setChannel("EMAIL");delivery.setDestination(email);
   provider.send(notification,delivery,"myaaptha-security-"+id);jdbc.update("UPDATE security_incidents SET email_status='SENT',email_attempts=email_attempts+1 WHERE id=?",id);
  }catch(Exception error){jdbc.update("UPDATE security_incidents SET email_attempts=email_attempts+1,email_status=CASE WHEN email_attempts>=4 THEN 'FAILED' ELSE 'PENDING' END,email_next_attempt=? WHERE id=?",Timestamp.from(Instant.now().plusSeconds(300)),id);}}
  jdbc.update("DELETE FROM security_incidents WHERE occurred_at<? AND (blocked_until IS NULL OR blocked_until<?)",Timestamp.from(Instant.now().minus(Duration.ofDays(90))),Timestamp.from(Instant.now()));
 }
}
