package com.myaaptha.domain.finance;

import static org.assertj.core.api.Assertions.*;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.notification.NotificationRepository;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest(properties="myaaptha.finance.renewal-reminders-enabled=false")
@Transactional
class RenewalServiceTest {
  @Autowired RenewalService service;
  @Autowired RenewalNoticeGuard guard;
  @Autowired NotificationRepository notices;
  @Autowired UserRepository users;
  @Autowired JdbcTemplate db;
  long member(){var u=new UserEntity();u.setUsername("renewal-"+UUID.randomUUID());u.setPasswordHash("synthetic");return users.saveAndFlush(u).getId();}
  RenewalService.Input input(LocalDate expiry,boolean enabled,boolean archived){return new RenewalService.Input("WARRANTY","Washing machine","Example service","INV-1",new BigDecimal("1200.50"),null,expiry,"Asia/Kolkata","Synthetic fixture",enabled,archived);}
  Instant morning(LocalDate date){return date.atTime(9,0).atZone(ZoneId.of("Asia/Kolkata")).toInstant();}
  long count(long id){return db.queryForObject("SELECT COUNT(*) FROM finance_renewal_notices WHERE renewal_id=?",Long.class,id);}

  @Test void allFiveMilestonesQueueOnceAndRestartDoesNotDuplicate(){
    long owner=member();LocalDate expiry=LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(60);
    var item=service.create(owner,input(expiry,true,false));
    assertThat(item.reminderDays()).containsExactly(30,15,7,3,1);
    for(int lead:RenewalService.REMINDER_DAYS){
      Instant now=morning(expiry.minusDays(lead));
      assertThat(service.due(now)).contains(item.id());
      service.dispatch(item.id(),now);service.dispatch(item.id(),now.plusSeconds(10));
    }
    assertThat(count(item.id())).isEqualTo(5);
    assertThat(service.list(owner).getFirst().nextReminderAt()).isNull();
    assertThat(notices.findTop100ByUserIdOrderByCreatedAtDesc(owner)).hasSize(5).allMatch(n->n.getType().equals("FINANCE_RENEWAL"));
  }
  @Test void queuedRemindersExpireAtLocalMidnightEvenWhenTheWarrantyIsStillActive(){
    long owner=member();LocalDate expiry=LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(60);
    var item=service.create(owner,input(expiry,true,false));
    for(int lead:RenewalService.REMINDER_DAYS){
      service.dispatch(item.id(),morning(expiry.minusDays(lead)));
      long notificationId=db.queryForObject("SELECT notification_id FROM finance_renewal_notices WHERE renewal_id=? AND reminder_days=?",Long.class,item.id(),lead);
      var notice=notices.findById(notificationId).orElseThrow();
      Instant midnight=expiry.minusDays(lead).plusDays(1).atStartOfDay(ZoneId.of("Asia/Kolkata")).toInstant();
      assertThat(guard.enabled(notice,midnight.minusSeconds(1))).isTrue();
      assertThat(guard.enabled(notice,midnight)).isFalse();
      assertThat(guard.enabled(notice,morning(expiry))).isFalse();
    }
  }
  @Test void renewRearmsCycleAndOldOutboxIsCancelled(){
    long owner=member();LocalDate expiry=LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(60);
    var item=service.create(owner,input(expiry,true,false));service.dispatch(item.id(),morning(expiry.minusDays(30)));
    var notice=notices.findTop100ByUserIdOrderByCreatedAtDesc(owner).getFirst();
    assertThat(guard.enabled(notice,morning(expiry.minusDays(30)))).isTrue();
    service.update(owner,item.id(),input(expiry.plusYears(1),true,false));
    assertThat(guard.enabled(notice)).isFalse();
    service.dispatch(item.id(),morning(expiry.plusYears(1).minusDays(30)));
    assertThat(count(item.id())).isEqualTo(2);
  }
  @Test void pauseArchiveAndDeleteCancelDeliveryAndPreventFutureReminders(){
    long owner=member();LocalDate expiry=LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(60);
    var item=service.create(owner,input(expiry,true,false));service.dispatch(item.id(),morning(expiry.minusDays(30)));
    var notice=notices.findTop100ByUserIdOrderByCreatedAtDesc(owner).getFirst();
    service.update(owner,item.id(),input(expiry,false,false));assertThat(guard.enabled(notice)).isFalse();
    assertThat(service.list(owner).getFirst().nextReminderAt()).isNull();
    service.update(owner,item.id(),input(expiry,true,true));
    service.dispatch(item.id(),morning(expiry.minusDays(15)));assertThat(count(item.id())).isEqualTo(1);
    service.delete(owner,item.id());assertThat(service.list(owner)).isEmpty();assertThat(guard.enabled(notice)).isFalse();
  }
  @Test void ownerIsolationAndInputValidation(){
    long owner=member(),other=member();LocalDate expiry=LocalDate.now().plusDays(60);
    var item=service.create(owner,input(expiry,true,false));
    assertThat(service.list(other)).isEmpty();
    assertThatThrownBy(()->service.update(other,item.id(),input(expiry,true,false))).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->service.delete(other,item.id())).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->service.attachment(other,item.id())).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->service.create(owner,new RenewalService.Input("WARRANTY","Bad","","",null,expiry.plusDays(1),expiry,"Asia/Kolkata",null,true,false))).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->service.create(owner,new RenewalService.Input("BILL","Bad","","",new BigDecimal("-1"),null,expiry,"Invalid/Zone",null,true,false))).isInstanceOf(ResponseStatusException.class);
  }
  @Test void stateChangesPreserveAConcurrentRenewalDateAndOtherFields(){
    long owner=member(),other=member();LocalDate expiry=LocalDate.now().plusDays(60);
    var stale=service.create(owner,input(expiry,true,false));
    service.update(owner,stale.id(),input(expiry.plusYears(1),true,false));
    var archived=service.state(owner,stale.id(),new RenewalService.State(null,true));
    assertThat(archived.expiresOn()).isEqualTo(expiry.plusYears(1));
    assertThat(archived.nextReminderAt()).isNull();
    var restored=service.state(owner,stale.id(),new RenewalService.State(null,false));
    assertThat(restored.expiresOn()).isEqualTo(expiry.plusYears(1));assertThat(restored.provider()).isEqualTo("Example service");
    assertThat(restored.nextReminderAt()).isNotNull();
    assertThatThrownBy(()->service.state(other,stale.id(),new RenewalService.State(null,true))).isInstanceOf(ResponseStatusException.class);
  }
  @Test void localDateDstAndMissedDaysDoNotSendFalseOrCatchupFloods(){
    var in=new RenewalService.Input("SERVICE","Annual plan",null,null,null,null,LocalDate.of(2027,3,22),"America/New_York",null,true,false);
    Instant now=Instant.parse("2027-03-07T16:00:00Z");
    assertThat(RenewalService.nextReminder(in,now,Set.of())).isEqualTo(now); // 15-day local milestone already reached 9am.
    assertThat(RenewalService.nextReminder(in,now,Set.of(15))).isEqualTo(Instant.parse("2027-03-15T13:00:00Z")); // DST changes 9am offset.
    assertThat(RenewalService.nextReminder(in,Instant.parse("2027-03-08T16:00:00Z"),Set.of())).isEqualTo(Instant.parse("2027-03-15T13:00:00Z"));
    assertThat(RenewalService.nextReminder(in,Instant.parse("2027-03-22T16:00:00Z"),Set.of())).isNull();
  }
  @Test void editsDoNotRearmAlreadySentMilestoneAndNewLateItemSchedulesOnlyFutureDays(){
    long owner=member();LocalDate expiry=LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(30);
    var item=service.create(owner,input(expiry,true,false));Instant now=item.nextReminderAt().plusSeconds(1);
    service.dispatch(item.id(),now);service.update(owner,item.id(),input(expiry,true,false));service.dispatch(item.id(),now.plusSeconds(30));
    assertThat(count(item.id())).isEqualTo(1);
    var late=input(LocalDate.of(2027,4,10),true,false);
    assertThat(RenewalService.nextReminder(late,Instant.parse("2027-04-08T08:00:00Z"),Set.of())).isEqualTo(Instant.parse("2027-04-09T03:30:00Z"));
  }
}
