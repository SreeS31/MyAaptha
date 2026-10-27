package com.myaaptha.domain.timeline;

import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest
class TimelineConcurrencyTest {
  @Autowired TimelineController timeline;
  @Autowired JdbcTemplate db;
  @Autowired UserRepository users;
  @Autowired PlatformTransactionManager transactions;

  long owner() {
    var user = new UserEntity();
    user.setUsername("timeline-race-" + UUID.randomUUID());
    user.setPasswordHash("fixture-only");
    long owner = users.saveAndFlush(user).getId();
    db.batchUpdate("INSERT INTO timeline_events(user_id,event_key,event_date,kind,title,detail) VALUES(?,?,'2026-10-18','Other','Fixture','')",
        java.util.stream.IntStream.range(0, 499).mapToObj(i -> new Object[]{owner, "fixture-" + i}).toList());
    return owner;
  }

  int save(long owner, String key) {
    try {
      timeline.save(() -> Long.toString(owner), key,
          new TimelineController.Event(key, "2026-10-18", "Other", "Saved concurrently", ""));
      return 200;
    } catch (ResponseStatusException exception) {
      return exception.getStatusCode().value();
    }
  }

  List<Integer> race(long owner, String firstKey, String secondKey) throws Exception {
    var locked = new CountDownLatch(1);
    var release = new CountDownLatch(1);
    var started = new CountDownLatch(2);
    try (var pool = Executors.newFixedThreadPool(3)) {
      var blocker = pool.submit(() -> new TransactionTemplate(transactions).execute(status -> {
        db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, owner);
        locked.countDown();
        try { if (!release.await(10, TimeUnit.SECONDS)) throw new IllegalStateException("Test lock timed out"); }
        catch (InterruptedException error) { Thread.currentThread().interrupt(); throw new IllegalStateException(error); }
        return null;
      }));
      try {
        assertTrue(locked.await(5, TimeUnit.SECONDS));
        var first = pool.submit(() -> { started.countDown(); return save(owner, firstKey); });
        var second = pool.submit(() -> { started.countDown(); return save(owner, secondKey); });
        assertTrue(started.await(5, TimeUnit.SECONDS));
        // A held owner lock must block even inserts of different event keys.
        assertThrows(TimeoutException.class, () -> first.get(150, TimeUnit.MILLISECONDS));
        assertThrows(TimeoutException.class, () -> second.get(150, TimeUnit.MILLISECONDS));
        release.countDown();
        blocker.get(10, TimeUnit.SECONDS);
        return List.of(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
      } finally { release.countDown(); }
    }
  }

  @Test void concurrentDifferentKeysCannotExceedTheFiveHundredEventLimit() throws Exception {
    long owner = owner();
    assertEquals(Set.of(200, 400), new HashSet<>(race(owner, "new-first", "new-second")));
    assertEquals(500, timeline.list(() -> Long.toString(owner)).size());
    assertEquals(200, save(owner, "fixture-0"));
    assertEquals(400, save(owner, "new-at-limit"));
  }

  @Test void concurrentSameKeyUpsertsDoNotProduceDuplicateInsertFailures() throws Exception {
    long owner = owner();
    assertEquals(List.of(200, 200), race(owner, "shared-key", "shared-key"));
    assertEquals(500, timeline.list(() -> Long.toString(owner)).size());
    assertEquals(1, db.queryForObject("SELECT count(*) FROM timeline_events WHERE user_id=? AND event_key='shared-key'", Integer.class, owner));
  }
}
