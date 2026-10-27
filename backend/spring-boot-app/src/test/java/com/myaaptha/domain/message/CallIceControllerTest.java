package com.myaaptha.domain.message;
import static org.assertj.core.api.Assertions.*;
import java.time.Instant;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class CallIceControllerTest {
 private static final String SECRET="synthetic-only-turn-signing-secret-123456789";
 @Test void localFallbackHasNoCredentialsAndCannotBeCached(){
   var response=new CallIceController("","",false,600).configuration(()->"7");
   assertThat(response.getHeaders().getCacheControl()).isEqualTo("no-store");
   assertThat(response.getBody().relayConfigured()).isFalse();
   assertThat(response.getBody().iceServers()).hasSize(1);
   assertThat(response.getBody().iceServers().getFirst().credential()).isNull();
 }
 @Test void credentialsUseCoturnHmacAndExpireWithoutExposingSigningSecret()throws Exception{
   long before=Instant.now().getEpochSecond();
   var config=new CallIceController("turn:turn.myaaptha.com:3478?transport=udp,turns:turn.myaaptha.com:5349?transport=tcp",SECRET,true,600).configuration(()->"7").getBody();
   assertThat(config.relayConfigured()).isTrue();
   assertThat(config.credentialsExpireAt()).isBetween(before+600,Instant.now().getEpochSecond()+600);
   var relay=config.iceServers().get(1);
   assertThat(relay.username()).isEqualTo(config.credentialsExpireAt()+":7");
   Mac mac=Mac.getInstance("HmacSHA1");mac.init(new SecretKeySpec(SECRET.getBytes(StandardCharsets.UTF_8),"HmacSHA1"));
   assertThat(relay.credential()).isEqualTo(Base64.getEncoder().encodeToString(mac.doFinal(relay.username().getBytes(StandardCharsets.UTF_8)))).doesNotContain(SECRET);
   assertThat(relay.urls()).hasSize(2);
 }
 @Test void identitiesAreBoundToTheAuthenticatedAccount(){
   var controller=new CallIceController("turn:turn.myaaptha.com:3478",SECRET,true,600);
   assertThat(controller.configuration(()->"7").getBody().iceServers().get(1).credential()).isNotEqualTo(controller.configuration(()->"8").getBody().iceServers().get(1).credential());
 }
 @Test void requiredRelayFailsClosedUntilConfigured(){
   for(String secret:new String[]{"","short","                                "})
     assertThatThrownBy(()->new CallIceController("turn:turn.myaaptha.com:3478",secret,true,600).configuration(()->"7"))
       .isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(503));
 }
 @Test void rejectsCredentialBearingOrHttpUrls(){
   for(String url:new String[]{"turn:user:password@turn.myaaptha.com:3478","https://turn.myaaptha.com:3478","turn:turn.myaaptha.com:3478/path","turn:turn.myaaptha.com:0","turn:turn.myaaptha.com:99999"})
     assertThatIllegalArgumentException().isThrownBy(()->new CallIceController(url,SECRET,true,600));
 }
 @Test void limitsCredentialLifetime(){
   for(int ttl:new int[]{0,59,3601})assertThatIllegalArgumentException().isThrownBy(()->new CallIceController("",SECRET,false,ttl));
 }
 @Test void anonymousRequestsCannotObtainCredentials(){
   assertThatThrownBy(()->new CallIceController("",SECRET,false,600).configuration(null))
     .isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(401));
 }
}
