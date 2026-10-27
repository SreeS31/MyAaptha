package com.myaaptha.domain.moderation;

import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.security.Principal;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest @Transactional
class ModerationQueueTest {
 @Autowired ModerationController controller;@Autowired AbuseReportRepository reports;@Autowired UserRepository users;
 Principal member(boolean admin){var u=new UserEntity();u.setUsername("queue-fixture-"+UUID.randomUUID());u.setPasswordHash("synthetic-only");u.setRole(admin?"ADMIN":"USER");long id=users.saveAndFlush(u).getId();return ()->Long.toString(id);}
 AbuseReportEntity report(Principal member,String status){var r=new AbuseReportEntity();r.setReporterUserId(Long.valueOf(member.getName()));r.setReason("SPAM");r.setStatus(status);return reports.saveAndFlush(r);}
 @Test void reachesOlderReportsBeyondTwoHundredWithoutDuplicatesWhenNewReportsArrive(){
  var admin=member(true);var reporter=member(false);var expected=new HashSet<Long>();for(int i=0;i<211;i++)expected.add(report(reporter,"OPEN").getId());
  var first=controller.queue(admin,"OPEN",null,50);assertEquals(50,first.items().size());assertNotNull(first.nextCursor());var seen=new HashSet<Long>();first.items().forEach(r->assertTrue(seen.add(r.id())));
  long inserted=report(reporter,"OPEN").getId();Long cursor=first.nextCursor();while(cursor!=null){var next=controller.queue(admin,"OPEN",cursor,50);next.items().forEach(r->assertTrue(seen.add(r.id())));cursor=next.nextCursor();}
  assertEquals(expected,seen);assertFalse(seen.contains(inserted));assertEquals(inserted,controller.queue(admin,"OPEN",null,50).items().getFirst().id());
 }
 @Test void statusFilteringHappensBeforePaginationAndInvalidInputsAreRejected(){
  var admin=member(true);var reporter=member(false);long old=report(reporter,"OPEN").getId();for(int i=0;i<205;i++)report(reporter,"RESOLVED");
  var open=controller.queue(admin,"OPEN",null,50);assertEquals(List.of(old),open.items().stream().map(ModerationController.ReportDto::id).toList());assertNull(open.nextCursor());
  for(String status:List.of("WRONG",""))assertEquals(400,assertThrows(ResponseStatusException.class,()->controller.queue(admin,status,null,50)).getStatusCode().value());
  assertThrows(ResponseStatusException.class,()->controller.queue(admin,"ALL",0L,50));assertThrows(ResponseStatusException.class,()->controller.queue(admin,"ALL",null,101));
 }
 @Test void ordinaryMembersCannotReadQueueOrUpdateAnotherReportAndMineRemainsScoped(){
  var reporter=member(false);var other=member(false);long id=report(reporter,"OPEN").getId();
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.queue(other,"ALL",null,50)).getStatusCode().value());
  assertEquals(403,assertThrows(ResponseStatusException.class,()->controller.moderate(other,id,new ModerationController.ModerateReport("RESOLVED","Denied"))).getStatusCode().value());
  assertTrue(controller.mine(other).isEmpty());assertEquals(1,controller.mine(reporter).size());
 }
}
