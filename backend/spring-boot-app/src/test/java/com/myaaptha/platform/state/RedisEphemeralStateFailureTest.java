package com.myaaptha.platform.state;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;

class RedisEphemeralStateFailureTest {
  @Test void unavailableOrFailedAtomicOperationCannotReportSuccessfulConsumption() {
    var redis=mock(StringRedisTemplate.class);
    var state=new RedisEphemeralState(redis,"synthetic-test");
    when(redis.execute(org.mockito.ArgumentMatchers.<RedisScript<Long>>any(),anyList(),any(Object[].class)))
        .thenReturn(null).thenThrow(new IllegalStateException("Synthetic unavailable Redis"));
    assertThrows(IllegalStateException.class,()->state.deleteIfValue("callback","validated"));
    assertThrows(IllegalStateException.class,()->state.deleteIfValue("callback","validated"));
    verify(redis,never()).delete(anyString());
  }
}
