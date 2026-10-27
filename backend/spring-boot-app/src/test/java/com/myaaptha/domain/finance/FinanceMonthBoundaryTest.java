package com.myaaptha.domain.finance;

import static org.assertj.core.api.Assertions.*;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest @Transactional
class FinanceMonthBoundaryTest {
  @Autowired FinanceService service;
  @Autowired UserRepository users;
  private Long member(){var u=new UserEntity();u.setUsername("month-"+UUID.randomUUID());u.setPasswordHash("test-only");return users.saveAndFlush(u).getId();}
  private FinanceService.Transaction add(Long owner,String amount,String at){return service.add(owner,new FinanceService.Input(new BigDecimal(amount),"EXPENSE","OTHER","Boundary fixture","Synthetic record",Instant.parse(at),"MANUAL",null,null));}

  @Test void midnightIsCountedInExactlyOneUtcMonthAndAccountsStayIsolated(){
    Long owner=member(),other=member();
    add(owner,"1","2026-09-30T23:59:59Z");
    add(owner,"2","2026-10-01T00:00:00Z");
    add(owner,"3","2026-10-31T23:59:59.999Z");
    add(owner,"4","2026-11-01T00:00:00Z");
    add(other,"1000","2026-10-01T00:00:00Z");
    assertThat(service.summary(owner,YearMonth.of(2026,9)).spending()).isEqualByComparingTo("1");
    var october=service.summary(owner,YearMonth.of(2026,10));
    assertThat(october.spending()).isEqualByComparingTo("5");assertThat(october.transactions()).hasSize(2);
    assertThat(service.summary(owner,YearMonth.of(2026,11)).spending()).isEqualByComparingTo("4");
  }
  @Test void leapDayYearRolloverAndSmsDuplicatesUseTheSameBoundaries(){
    Long owner=member();add(owner,"5","2024-02-29T23:59:59Z");add(owner,"6","2024-03-01T00:00:00Z");
    assertThat(service.summary(owner,YearMonth.of(2024,2)).spending()).isEqualByComparingTo("5");
    add(owner,"7","2026-12-31T23:59:59Z");add(owner,"8","2027-01-01T00:00:00Z");
    assertThat(service.summary(owner,YearMonth.of(2026,12)).spending()).isEqualByComparingTo("7");
    var sms=new FinanceService.Input(null,null,null,null,null,Instant.parse("2026-10-01T00:00:00Z"),"SMS","Rs. 1,249.50 debited at APOLLO PHARMACY","TESTBANK");
    var first=service.add(owner,sms);var again=service.add(owner,sms);
    assertThat(first.id()).isEqualTo(again.id());assertThat(first.category()).isEqualTo("HEALTH");
    assertThat(service.summary(owner,YearMonth.of(2026,9)).transactions()).isEmpty();
    assertThat(service.summary(owner,YearMonth.of(2026,10)).spending()).isEqualByComparingTo("1249.50");
  }
}
