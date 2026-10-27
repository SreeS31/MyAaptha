package com.myaaptha.domain.finance;

import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class RenewalReminderScheduler {
  private static final Logger LOG=LoggerFactory.getLogger(RenewalReminderScheduler.class);
  private final RenewalService renewals;
  private final boolean enabled;
  public RenewalReminderScheduler(RenewalService renewals,@Value("${myaaptha.finance.renewal-reminders-enabled:true}") boolean enabled){this.renewals=renewals;this.enabled=enabled;}
  @Scheduled(fixedDelayString="${myaaptha.finance.renewal-reminders-delay-ms:60000}")
  public void dispatch(){
    if(!enabled)return;
    Instant now=Instant.now();
    for(long id:renewals.due(now))try{renewals.dispatch(id,now);}catch(RuntimeException error){
      // Never log invoice names, provider details or notification destinations.
      LOG.warn("A renewal reminder could not be queued; it remains due for retry");
    }
  }
}
