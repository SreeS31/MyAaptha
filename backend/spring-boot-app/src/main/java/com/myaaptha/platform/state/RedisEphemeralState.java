package com.myaaptha.platform.state;

import java.time.Duration;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name="myaaptha.state.provider", havingValue="redis")
public class RedisEphemeralState implements EphemeralState {
  private static final DefaultRedisScript<Long> DELETE_IF_VALUE = new DefaultRedisScript<>(
      "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]); end; return 0",Long.class);
  private static final DefaultRedisScript<Long> INCREMENT = new DefaultRedisScript<>(
      "local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('PEXPIRE',KEYS[1],ARGV[1]); end; return n", Long.class);
  private final StringRedisTemplate redis;
  private final String prefix;
  public RedisEphemeralState(StringRedisTemplate redis, @Value("${myaaptha.state.namespace:myaaptha}") String prefix) {
    this.redis=redis; this.prefix=prefix + ":";
  }
  public long increment(String key, Duration ttl) {
    Long count=redis.execute(INCREMENT, List.of(prefix+key), String.valueOf(ttl.toMillis()));
    if (count==null) throw new IllegalStateException("Shared counter unavailable");
    return count;
  }
  public void put(String key,String value,Duration ttl) { redis.opsForValue().set(prefix+key,value,ttl); }
  public String get(String key) { return redis.opsForValue().get(prefix+key); }
  public List<String> getAll(List<String> keys) {
    if(keys.isEmpty()) return List.of();
    List<String> result=redis.opsForValue().multiGet(keys.stream().map(key->prefix+key).toList());
    if(result==null) throw new IllegalStateException("Shared state unavailable");
    return result;
  }
  public void delete(String key) { redis.delete(prefix+key); }
  public boolean deleteIfValue(String key,String expectedValue) {
    java.util.Objects.requireNonNull(expectedValue,"Expected state value is required");
    Long removed=redis.execute(DELETE_IF_VALUE,List.of(prefix+key),expectedValue);
    if(removed==null) throw new IllegalStateException("Shared state unavailable");
    return removed==1L;
  }
}
