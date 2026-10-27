package com.myaaptha.platform.state;
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.data.redis.connection.*;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import java.time.Duration;
@EnabledIfEnvironmentVariable(named="REDIS_TEST_HOST",matches=".+")
class RedisEphemeralStateTest {
  @Test void separateClientsShareAtomicBudgetsPresenceAndExpiry()throws Exception{
    var config=new RedisStandaloneConfiguration(System.getenv("REDIS_TEST_HOST"),Integer.parseInt(System.getenv().getOrDefault("REDIS_TEST_PORT","6379")));
    config.setPassword(RedisPassword.of(System.getenv("REDIS_TEST_PASSWORD")));
    var first=new LettuceConnectionFactory(config);var second=new LettuceConnectionFactory(config);first.afterPropertiesSet();second.afterPropertiesSet();
    try {
      var namespace="test:"+java.util.UUID.randomUUID();
      var a=new RedisEphemeralState(new StringRedisTemplate(first),namespace);var b=new RedisEphemeralState(new StringRedisTemplate(second),namespace);
      try(var executor=java.util.concurrent.Executors.newFixedThreadPool(8)){
        var tasks=new java.util.ArrayList<java.util.concurrent.Future<Long>>();
        for(int i=0;i<200;i++){var client=i%2==0?a:b;tasks.add(executor.submit(()->client.increment("counter",Duration.ofSeconds(10))));}
        var values=new java.util.HashSet<Long>();for(var task:tasks)values.add(task.get());assertEquals(200,values.size());assertTrue(values.contains(200L));
      }
      a.put("presence","online",Duration.ofMillis(200));assertEquals("online",b.get("presence"));
      assertEquals(java.util.Arrays.asList("online",null),b.getAll(java.util.List.of("presence","missing")));
      Thread.sleep(250);assertNull(b.get("presence"));a.delete("counter");
      a.put("callback","validated",Duration.ofSeconds(10));
      assertFalse(b.deleteIfValue("callback","wrong-owner"));
      assertEquals("validated",a.get("callback"));
      a.put("callback","replacement",Duration.ofSeconds(10));
      assertFalse(b.deleteIfValue("callback","validated"));
      assertEquals("replacement",a.get("callback"));
      try(var executor=java.util.concurrent.Executors.newFixedThreadPool(8)) {
        var start=new java.util.concurrent.CountDownLatch(1);
        var attempts=new java.util.ArrayList<java.util.concurrent.Future<Boolean>>();
        for(int i=0;i<32;i++) {
          var client=i%2==0?a:b;
          attempts.add(executor.submit(()->{start.await();return client.deleteIfValue("callback","replacement");}));
        }
        start.countDown();int winners=0;
        for(var attempt:attempts) if(attempt.get(5,java.util.concurrent.TimeUnit.SECONDS)) winners++;
        assertEquals(1,winners);assertNull(a.get("callback"));
      }
      assertFalse(b.deleteIfValue("missing","value"));
      a.put("expired","value",Duration.ofMillis(100));Thread.sleep(150);
      assertFalse(b.deleteIfValue("expired","value"));
      assertThrows(NullPointerException.class,()->b.deleteIfValue("missing",null));
    } finally {first.destroy();second.destroy();}
  }
}
