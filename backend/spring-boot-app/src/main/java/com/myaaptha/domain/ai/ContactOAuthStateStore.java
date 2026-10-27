package com.myaaptha.domain.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.security.FieldEncryption;
import com.myaaptha.platform.state.EphemeralState;
import com.myaaptha.platform.state.RedisEphemeralState;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.util.HexFormat;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

/** Ten-minute, one-use OAuth handoffs. Redis is shared; memory is development only. */
@Component
public class ContactOAuthStateStore {
  private static final Duration TTL=Duration.ofMinutes(10);
  private static final int MAX_JSON_BYTES=20*1024*1024;
  private final EphemeralState state;
  private final FieldEncryption encryption;
  private final ObjectMapper json;
  private final Clock clock=Clock.systemUTC();

  public ContactOAuthStateStore(EphemeralState state,FieldEncryption encryption,ObjectMapper json) {
    if(state instanceof RedisEphemeralState && !encryption.isEnabled())
      throw new IllegalStateException("Shared contact OAuth state requires sensitive-field encryption");
    this.state=state;this.encryption=encryption;this.json=json;
  }

  public void putPending(String token,Pending pending) {
    write("pending",token,pending.userId(),json.valueToTree(pending));
  }

  public Pending takePending(String token,String provider) {
    Snapshot snapshot=read("pending",token);
    if(snapshot==null) return null;
    Pending pending;
    try { pending=json.treeToValue(snapshot.envelope().payload(),Pending.class); }
    catch(Exception error) { throw unavailable(); }
    if(pending==null || !snapshot.envelope().owner().equals(pending.userId())
        || pending.provider()==null || pending.verifier()==null || pending.resultKey()==null)
      throw unavailable();
    if(!pending.provider().equals(provider)) return null;
    return remove(snapshot)?pending:null;
  }

  public void putResult(String token,Long owner,Object result) {
    write("result",token,owner,json.valueToTree(result));
  }

  public Object takeResult(String token,Long owner) {
    Snapshot snapshot=read("result",token);
    // Do not consume another account's result, even with a valid opaque token.
    if(snapshot==null || !snapshot.envelope().owner().equals(owner)) throw missing();
    Object value=json.convertValue(snapshot.envelope().payload(),Object.class);
    if(!remove(snapshot)) throw missing();
    return value;
  }

  private void write(String purpose,String token,Long owner,JsonNode payload) {
    String key=key(purpose,token);
    if(key==null || owner==null || owner<=0 || payload==null || payload.isNull()) throw unavailable();
    try {
      var envelope=new Envelope(1,purpose,key,owner,clock.millis()+TTL.toMillis(),payload);
      String plaintext=json.writeValueAsString(envelope);
      if(plaintext.getBytes(StandardCharsets.UTF_8).length>MAX_JSON_BYTES)
        throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"The contact preview is too large. Try a smaller import.");
      state.put(key,encryption.encrypt(plaintext),TTL);
    } catch(ResponseStatusException error) { throw error; }
    catch(Exception error) { throw unavailable(); }
  }

  private Snapshot read(String purpose,String token) {
    String key=key(purpose,token);
    if(key==null) return null;
    try {
      String raw=state.get(key);
      if(raw==null) return null;
      if(raw.length()>MAX_JSON_BYTES*2) throw unavailable();
      // OAuth has no legacy plaintext migration, even when other fields allow one.
      if(encryption.isEnabled() && !raw.startsWith("enc:v1:")) throw unavailable();
      String plaintext=encryption.decrypt(raw);
      if(plaintext.getBytes(StandardCharsets.UTF_8).length>MAX_JSON_BYTES) throw unavailable();
      Envelope envelope=json.readValue(plaintext,Envelope.class);
      if(envelope.version()!=1 || !purpose.equals(envelope.purpose()) || !key.equals(envelope.binding())
          || envelope.owner()==null || envelope.owner()<=0 || envelope.payload()==null || envelope.payload().isNull())
        throw unavailable();
      if(envelope.expiresAtMillis()<=clock.millis()) { state.deleteIfValue(key,raw);return null; }
      return new Snapshot(key,raw,envelope);
    } catch(Exception error) { throw unavailable(); }
  }

  private boolean remove(Snapshot snapshot) {
    try { return state.deleteIfValue(snapshot.key(),snapshot.raw()); }
    catch(Exception error) { throw unavailable(); }
  }

  private String key(String purpose,String token) {
    if(token==null || !token.matches("[A-Za-z0-9_-]{43}")) return null;
    try {
      byte[] hash=MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.US_ASCII));
      return "contact-oauth:v1:"+purpose+":"+HexFormat.of().formatHex(hash);
    } catch(Exception error) { throw unavailable(); }
  }

  private ResponseStatusException unavailable() {
    return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Contact authorization is temporarily unavailable. Please try again.");
  }
  private ResponseStatusException missing() {
    return new ResponseStatusException(HttpStatus.NOT_FOUND,"This contact import result expired or was already read");
  }
  public record Pending(Long userId,String provider,String verifier,String resultKey,boolean privateBook) {}
  private record Envelope(int version,String purpose,String binding,Long owner,long expiresAtMillis,JsonNode payload) {}
  private record Snapshot(String key,String raw,Envelope envelope) {}
}
