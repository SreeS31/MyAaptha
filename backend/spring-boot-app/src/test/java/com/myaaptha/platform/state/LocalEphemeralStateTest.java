package com.myaaptha.platform.state;

import static org.junit.jupiter.api.Assertions.*;
import java.time.Duration;
import java.util.ArrayList;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;

class LocalEphemeralStateTest {
  @Test void idleMaintenanceRemovesExpiredEntriesAndPreservesLiveOnes() {
    var state=new LocalEphemeralState();
    var now=java.time.Instant.parse("2026-10-18T00:00:00Z");
    org.springframework.test.util.ReflectionTestUtils.setField(state,"clock",java.time.Clock.fixed(now,java.time.ZoneOffset.UTC));
    state.put("expired","private-value",Duration.ofSeconds(10));
    state.put("live","still-needed",Duration.ofSeconds(20));
    org.springframework.test.util.ReflectionTestUtils.setField(state,"clock",java.time.Clock.fixed(now.plusSeconds(10),java.time.ZoneOffset.UTC));
    state.cleanupExpired();
    var entries=(java.util.Map<?,?>)org.springframework.test.util.ReflectionTestUtils.getField(state,"entries");
    assertEquals(java.util.Set.of("live"),entries.keySet());
    assertEquals("still-needed",state.get("live"));
  }
  @Test void wrongOrStaleValueCannotDeleteReplacement() {
    var state=new LocalEphemeralState();
    state.put("result","owner-a",Duration.ofMinutes(1));
    assertFalse(state.deleteIfValue("result","owner-b"));
    assertEquals("owner-a",state.get("result"));
    state.put("result","replacement",Duration.ofMinutes(1));
    assertFalse(state.deleteIfValue("result","owner-a"));
    assertEquals("replacement",state.get("result"));
    assertTrue(state.deleteIfValue("result","replacement"));
    assertFalse(state.deleteIfValue("result","replacement"));
  }

  @Test void onlyOneConcurrentConsumerWins() throws Exception {
    var state=new LocalEphemeralState();
    state.put("callback","validated",Duration.ofMinutes(1));
    try(var executor=Executors.newFixedThreadPool(8)) {
      var start=new CountDownLatch(1);
      var attempts=new ArrayList<Future<Boolean>>();
      for(int i=0;i<32;i++) attempts.add(executor.submit(()->{
        start.await();return state.deleteIfValue("callback","validated");
      }));
      start.countDown();int winners=0;
      for(var attempt:attempts) if(attempt.get(5,TimeUnit.SECONDS)) winners++;
      assertEquals(1,winners);assertNull(state.get("callback"));
    }
  }

  @Test void expiredOrMissingValuesCannotBeConsumedAndNullIsRejected() {
    var state=new LocalEphemeralState();
    state.put("expired","value",Duration.ZERO);
    assertFalse(state.deleteIfValue("expired","value"));
    assertFalse(state.deleteIfValue("missing","value"));
    assertThrows(NullPointerException.class,()->state.deleteIfValue("missing",null));
  }
}
