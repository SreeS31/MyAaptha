package com.myaaptha.domain.message;

import java.nio.charset.StandardCharsets;
import java.security.Principal;
import java.time.Instant;
import java.util.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import com.fasterxml.jackson.annotation.JsonInclude;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Coturn REST credentials: the shared signing secret never leaves the server. */
@RestController
@RequestMapping("/api/network/calls")
public class CallIceController {
  private final List<String> urls;
  private final String secret;
  private final boolean required;
  private final int ttl;
  public CallIceController(
      @Value("${myaaptha.calls.turn-urls:}") String urls,
      @Value("${myaaptha.calls.turn-secret:}") String secret,
      @Value("${myaaptha.calls.relay-required:false}") boolean required,
      @Value("${myaaptha.calls.credential-seconds:3600}") int ttl) {
    this.urls=Arrays.stream(urls.split(",")).map(String::trim).filter(s->!s.isEmpty()).distinct().toList();
    if(this.urls.size()>6 || this.urls.stream().anyMatch(s->{
      var matcher=java.util.regex.Pattern.compile("turns?:[A-Za-z0-9.-]+:([0-9]{1,5})(?:\\?transport=(?:udp|tcp))?").matcher(s);
      return !matcher.matches()||Integer.parseInt(matcher.group(1))<1||Integer.parseInt(matcher.group(1))>65535;
    }))
      throw new IllegalArgumentException("Use TURN host:port URLs without embedded credentials");
    if(ttl<60||ttl>3600)throw new IllegalArgumentException("TURN credential lifetime must be between 60 and 3600 seconds");
    this.secret=secret.trim();this.required=required;this.ttl=ttl;
  }
  @GetMapping("/ice")
  public ResponseEntity<Configuration> configuration(Principal principal) {
    if(principal==null)throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Sign in to configure calls");
    boolean configured=!urls.isEmpty()&&secret.length()>=32;
    if(required&&!configured)throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Call relay is not configured. Please contact support.");
    List<IceServer> servers=new ArrayList<>();
    servers.add(new IceServer(List.of("stun:stun.l.google.com:19302"),null,null));
    long expires=Instant.now().getEpochSecond()+ttl;
    if(configured){
      // Principal names in this application are numeric user IDs, not user-controlled strings.
      Long userId=Long.valueOf(principal.getName());
      String username=expires+":"+userId;
      try {
        Mac mac=Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8),"HmacSHA1"));
        String credential=Base64.getEncoder().encodeToString(mac.doFinal(username.getBytes(StandardCharsets.UTF_8)));
        servers.add(new IceServer(urls,username,credential));
      } catch(java.security.GeneralSecurityException e){throw new IllegalStateException("Call relay signing unavailable",e);}
    }
    return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("Pragma","no-cache")
        .body(new Configuration(servers,configured,configured?expires:null));
  }
  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record IceServer(List<String> urls,String username,String credential){}
  public record Configuration(List<IceServer> iceServers,boolean relayConfigured,Long credentialsExpireAt){}
}
