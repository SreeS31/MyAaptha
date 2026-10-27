package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.security.FieldEncryption;
import com.myaaptha.platform.state.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

class ContactOAuthStateStoreTest {
  final LocalEphemeralState state=new LocalEphemeralState();
  final ContactOAuthStateStore first=ContactOAuthTestSupport.store(state);
  final ContactOAuthStateStore second=ContactOAuthTestSupport.store(state);
  final String token="A".repeat(43),other="B".repeat(43);
  final ContactOAuthStateStore.Pending pending=new ContactOAuthStateStore.Pending(42L,"google","synthetic-pkce",other,true);

  @Test void independentStoresShareEncryptedPendingAndKeepWrongProviderFromConsuming() {
    first.putPending(token,pending);
    assertNull(second.takePending(token,"microsoft"));
    assertEquals(pending,second.takePending(token,"google"));
    assertNull(first.takePending(token,"google"));
  }

  @Test void ownerCheckedBeforeOneTimeRemovalAndWireResultIsPreserved() {
    var payload=Map.of("status","review","contacts",List.of(Map.of("displayName","Synthetic contact","phones",List.of("+15551230001"),"groups",List.of("Friends"))));
    first.putResult(token,42L,payload);
    assertEquals(404,assertThrows(ResponseStatusException.class,()->second.takeResult(token,43L)).getStatusCode().value());
    assertEquals(payload,second.takeResult(token,42L));
    assertEquals(404,assertThrows(ResponseStatusException.class,()->first.takeResult(token,42L)).getStatusCode().value());
  }

  @Test void cipherTextAndHashedKeysHidePkceAndContactDetails() {
    first.putPending(token,pending);
    first.putResult(other,42L,Map.of("displayName","Private synthetic name","email","private@example.test"));
    var entries=(Map<?,?>)ReflectionTestUtils.getField(state,"entries");
    assertEquals(2,entries.size());
    for(var key:entries.keySet()) {
      assertFalse(key.toString().contains(token));
      assertFalse(key.toString().contains(other));
      String raw=state.get(key.toString());
      assertTrue(raw.startsWith("enc:v1:primary:"));
      assertFalse(raw.contains("synthetic-pkce"));assertFalse(raw.contains("Private synthetic name"));
      assertFalse(raw.contains("private@example.test"));
    }
  }

  @Test void swappingValidEncryptedPayloadsBetweenKeysOrPurposesFailsClosed() {
    first.putPending(token,pending);
    first.putResult(other,42L,List.of());
    var keys=new ArrayList<>(((Map<?,?>)ReflectionTestUtils.getField(state,"entries")).keySet());
    String pendingKey=keys.stream().map(Object::toString).filter(k->k.contains(":pending:")).findFirst().orElseThrow();
    String resultKey=keys.stream().map(Object::toString).filter(k->k.contains(":result:")).findFirst().orElseThrow();
    state.put(resultKey,state.get(pendingKey),Duration.ofMinutes(10));
    assertEquals(503,assertThrows(ResponseStatusException.class,()->second.takeResult(other,42L)).getStatusCode().value());
    first.putResult(other,42L,List.of());
    first.putResult(token,42L,List.of("replacement"));
    var all=((Map<?,?>)ReflectionTestUtils.getField(state,"entries")).keySet();
    String secondResult=all.stream().map(Object::toString).filter(k->k.contains(":result:")&&!k.equals(resultKey)).findFirst().orElseThrow();
    state.put(secondResult,state.get(resultKey),Duration.ofMinutes(10));
    assertEquals(503,assertThrows(ResponseStatusException.class,()->first.takeResult(token,42L)).getStatusCode().value());
  }

  @Test void expiryIsEnforcedEvenWhenBackingStoreHasLongerRetention() {
    Instant now=Instant.parse("2026-10-19T00:00:00Z");
    ReflectionTestUtils.setField(first,"clock",Clock.fixed(now,ZoneOffset.UTC));
    first.putPending(token,pending);first.putResult(other,42L,List.of());
    ReflectionTestUtils.setField(second,"clock",Clock.fixed(now.plusSeconds(600),ZoneOffset.UTC));
    assertNull(second.takePending(token,"google"));
    assertEquals(404,assertThrows(ResponseStatusException.class,()->second.takeResult(other,42L)).getStatusCode().value());
    assertTrue(((Map<?,?>)ReflectionTestUtils.getField(state,"entries")).isEmpty());
  }

  @Test void concurrentResultReadersHaveExactlyOneWinner() throws Exception {
    first.putResult(token,42L,List.of(Map.of("name","Synthetic")));
    try(var executor=Executors.newFixedThreadPool(8)) {
      var gate=new CountDownLatch(1);var attempts=new ArrayList<Future<Boolean>>();
      for(int i=0;i<32;i++) {
        var store=i%2==0?first:second;
        attempts.add(executor.submit(()->{gate.await();try {store.takeResult(token,42L);return true;}
          catch(ResponseStatusException missing) {assertEquals(404,missing.getStatusCode().value());return false;}}));
      }
      gate.countDown();int winners=0;
      for(var attempt:attempts) if(attempt.get(10,TimeUnit.SECONDS)) winners++;
      assertEquals(1,winners);
    }
  }

  @Test void malformedInputsNeverReadSharedStateAndMissingStateIsNotAnErrorForCallbacks() {
    var backing=mock(EphemeralState.class);var store=ContactOAuthTestSupport.store(backing);
    for(String invalid:Arrays.asList(null,"","x","!".repeat(43),"A".repeat(44))) {
      assertNull(store.takePending(invalid,"google"));
      assertEquals(404,assertThrows(ResponseStatusException.class,()->store.takeResult(invalid,42L)).getStatusCode().value());
    }
    verifyNoInteractions(backing);
  }

  @Test void sharedRedisCannotBeConfiguredWithEncryptionDisabled() {
    var redis=mock(org.springframework.data.redis.core.StringRedisTemplate.class);
    var backing=new RedisEphemeralState(redis,"synthetic-test");
    assertThrows(IllegalStateException.class,()->new ContactOAuthStateStore(backing,new FieldEncryption(new MockEnvironment()),new ObjectMapper()));
    verifyNoInteractions(redis);
  }

  @Test void oversizedResultIsRejectedBeforeWritingSharedState() {
    var backing=mock(EphemeralState.class);var store=ContactOAuthTestSupport.store(backing);
    assertEquals(413,assertThrows(ResponseStatusException.class,()->store.putResult(token,42L,"X".repeat(20*1024*1024))).getStatusCode().value());
    verifyNoInteractions(backing);
  }

  @Test void corruptedCiphertextAndStorageFailuresReturnSafe503WithoutFallback() {
    first.putResult(token,42L,List.of());
    String key=((Map<?,?>)ReflectionTestUtils.getField(state,"entries")).keySet().iterator().next().toString();
    state.put(key,"enc:v1:primary:tampered-private-data",Duration.ofMinutes(10));
    var error=assertThrows(ResponseStatusException.class,()->second.takeResult(token,42L));
    assertEquals(503,error.getStatusCode().value());assertFalse(error.getReason().contains("private-data"));
    var backing=mock(EphemeralState.class);when(backing.get(anyString())).thenThrow(new IllegalStateException("Synthetic secret backend error"));
    var store=ContactOAuthTestSupport.store(backing);
    assertEquals(503,assertThrows(ResponseStatusException.class,()->store.takePending(token,"google")).getStatusCode().value());
    doThrow(new IllegalStateException("Synthetic failure")).when(backing).put(anyString(),anyString(),any());
    assertEquals(503,assertThrows(ResponseStatusException.class,()->store.putPending(token,pending)).getStatusCode().value());
  }

  @Test void legacyFieldMigrationSettingCannotPermitPlaintextOAuthPayloads() {
    first.putResult(token,42L,List.of());
    String key=((Map<?,?>)ReflectionTestUtils.getField(state,"entries")).keySet().iterator().next().toString();
    String plaintext=ContactOAuthTestSupport.encryption().decrypt(state.get(key));
    state.put(key,plaintext,Duration.ofMinutes(10));
    var encryption=new FieldEncryption(new MockEnvironment().withProperty("security.fields.enabled","true")
        .withProperty("security.fields.keys","primary="+Base64.getEncoder().encodeToString(new byte[32]))
        .withProperty("security.fields.allow-legacy-reads","true"));
    var reader=new ContactOAuthStateStore(state,encryption,new ObjectMapper());
    assertEquals(503,assertThrows(ResponseStatusException.class,()->reader.takeResult(token,42L)).getStatusCode().value());
  }
}
