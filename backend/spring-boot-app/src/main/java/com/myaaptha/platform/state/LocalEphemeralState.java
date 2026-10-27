package com.myaaptha.platform.state;

import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Bounded development fallback. Production requires Redis. */
@Component
@ConditionalOnProperty(name="myaaptha.state.provider", havingValue="memory", matchIfMissing=true)
public class LocalEphemeralState implements EphemeralState {
  private record Entry(String value,long expires) {}
  private final java.time.Clock clock=java.time.Clock.systemUTC();
  private final Map<String,Entry> entries=new HashMap<>();
  private void capacity(String key) {
    if(entries.size()<20000||entries.containsKey(key)) return;
    cleanupExpired();
    if(entries.size()>=20000) throw new IllegalStateException("Development state capacity reached");
  }
  public synchronized long increment(String key,Duration ttl) {
    capacity(key); long now=clock.millis(); Entry old=entries.get(key);
    long count=old==null||old.expires<=now?1:Long.parseLong(old.value)+1;
    entries.put(key,new Entry(String.valueOf(count),count==1?now+ttl.toMillis():old.expires)); return count;
  }
  public synchronized void put(String key,String value,Duration ttl) { capacity(key);entries.put(key,new Entry(value,clock.millis()+ttl.toMillis())); }
  public synchronized String get(String key) {
    Entry item=entries.get(key); if(item==null) return null;
    if(item.expires<=clock.millis()){entries.remove(key);return null;} return item.value;
  }
  public synchronized List<String> getAll(List<String> keys) { return keys.stream().map(this::get).toList(); }
  public synchronized void delete(String key) { entries.remove(key); }
  @org.springframework.scheduling.annotation.Scheduled(fixedDelay=60000)
  public synchronized void cleanupExpired() {
    long now=clock.millis();entries.values().removeIf(entry->entry.expires<=now);
  }
  public synchronized boolean deleteIfValue(String key,String expectedValue) {
    java.util.Objects.requireNonNull(expectedValue,"Expected state value is required");
    String current=get(key);
    if(!expectedValue.equals(current)) return false;
    entries.remove(key);return true;
  }
}
