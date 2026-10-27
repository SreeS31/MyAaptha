package com.myaaptha.domain.notification;
import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.notification.model.*;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
@SpringBootTest
class NotificationDeliveryLeaseTest {
  @Autowired NotificationDeliveryLease leases;
  @Autowired NotificationDeliveryRepository deliveries;
  @Autowired NotificationRepository notifications;
  @Autowired com.myaaptha.domain.user.UserRepository users;
  @Test void claimsAreExclusiveExpiredClaimsRecoverAndStaleCompletionIsFenced()throws Exception{
    var user=new com.myaaptha.domain.user.model.UserEntity();user.setUsername("lease-"+java.util.UUID.randomUUID());user.setPasswordHash("test-only");user=users.save(user);
    var notification=new NotificationEntity();notification.setUserId(user.getId());notification.setType("TEST");notification.setTitle("Lease test");notification.setBody("No external delivery");notification=notifications.save(notification);
    var row=new NotificationDeliveryEntity();row.setNotificationId(notification.getId());row.setChannel("TEST");row.setDestination("test.invalid");row.setNextAttemptAt(Instant.EPOCH);row=deliveries.saveAndFlush(row);
    final Long id=row.getId();
    try {
      try(var executor=java.util.concurrent.Executors.newFixedThreadPool(2)){
        var a=executor.submit(()->leases.claim());var b=executor.submit(()->leases.claim());
        var claims=java.util.stream.Stream.of(a.get(),b.get()).flatMap(java.util.Optional::stream).filter(d->d.getId().equals(id)).toList();
        assertEquals(1,claims.size());var old=claims.getFirst();
        var expired=deliveries.findById(id).orElseThrow();expired.setLeaseUntil(Instant.EPOCH);deliveries.saveAndFlush(expired);
        var recovered=leases.claim().orElseThrow();assertEquals(id,recovered.getId());assertEquals(2,recovered.getAttempts());assertNotEquals(old.getClaimToken(),recovered.getClaimToken());
        leases.finish(old,"SENT","stale",null,Instant.now());assertEquals("PROCESSING",deliveries.findById(id).orElseThrow().getStatus());
        leases.finish(recovered,"SENT","accepted",null,Instant.now());assertEquals("SENT",deliveries.findById(id).orElseThrow().getStatus());
      }
    } finally {deliveries.deleteById(id);notifications.deleteById(notification.getId());users.deleteById(user.getId());}
  }
}
