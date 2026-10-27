package com.myaaptha.domain.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.security.FieldEncryption;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class HelpAnswerMemory {
  public record Stored(String question, List<HelpChatController.Turn> history, HelpChatController.Reply reply) {}
  public record Shared(String question, String answer, List<String> sourceIds) {}
  private final JdbcTemplate jdbc;
  private final ObjectMapper json;
  private final FieldEncryption encryption;
  private final String version;
  public HelpAnswerMemory(JdbcTemplate jdbc, ObjectMapper json, FieldEncryption encryption, HelpKnowledge knowledge) {
    this.jdbc=jdbc;this.json=json;this.encryption=encryption;
    this.version=hash(encode(knowledge.all()));
  }
  static String normalize(String value) {
    // Preserve punctuation, numbers and negation; no fuzzy matching of different intents.
    return java.text.Normalizer.normalize(value,java.text.Normalizer.Form.NFC).trim().replaceAll("\\s+"," ").toLowerCase(Locale.ROOT);
  }
  static String hash(String value) {
    try {return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}
    catch(Exception e){throw new IllegalStateException(e);}
  }
  private String encode(Object value) {try{return json.writeValueAsString(value);}catch(Exception e){throw new IllegalStateException(e);}}
  private <T> T decode(String value,Class<T> type) {try{return json.readValue(value,type);}catch(Exception e){throw new IllegalStateException(e);}}
  public String key(String question,List<HelpChatController.Turn> history,String model) {
    return hash(version+"|help-v2|"+model+"|"+normalize(question)+"|"+encode(history));
  }
  public boolean enhancedEnabled() {return Boolean.TRUE.equals(jdbc.queryForObject("SELECT enhanced_enabled FROM help_ai_settings WHERE id=1",Boolean.class));}
  public void enhancedEnabled(boolean enabled) {jdbc.update("UPDATE help_ai_settings SET enhanced_enabled=? WHERE id=1",enabled);}
  public Optional<HelpChatController.Reply> find(long user,String key,int retentionDays) {
    if(retentionDays==0)return Optional.empty();
    return jdbc.query("SELECT payload FROM help_exchanges WHERE user_id=? AND cache_key=? AND mode IN ('AI','CACHE') AND expires_at>? AND created_at>? ORDER BY created_at DESC LIMIT 1",
      (rs,n)->decode(encryption.decrypt(rs.getString(1)),Stored.class).reply(),user,key,Timestamp.from(Instant.now()),Timestamp.from(Instant.now().minusSeconds(retentionDays*86400L))).stream().findFirst();
  }
  public Optional<Shared> shared(String question) {
    return jdbc.query("SELECT payload FROM help_shared_answers WHERE question_key=? AND knowledge_version=? AND expires_at>?",
      (rs,n)->decode(rs.getString(1),Shared.class),hash(normalize(question)),version,Timestamp.from(Instant.now())).stream().findFirst();
  }
  public Stored owned(long user,String id,int retentionDays) {
    if(retentionDays==0)throw new ResponseStatusException(HttpStatus.CONFLICT,"Enable AI history retention to retry a saved answer");
    return jdbc.query("SELECT payload FROM help_exchanges WHERE id=? AND user_id=? AND expires_at>? AND created_at>?",
      (rs,n)->decode(encryption.decrypt(rs.getString(1)),Stored.class),id,user,Timestamp.from(Instant.now()),Timestamp.from(Instant.now().minusSeconds(retentionDays*86400L)))
      .stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Saved answer not found"));
  }
  public HelpChatController.Reply save(long user,String key,String question,List<HelpChatController.Turn> history,HelpChatController.Reply reply,int days,int input,int output) {
    if(days==0)return reply;
    String id=UUID.randomUUID().toString();
    var saved=new HelpChatController.Reply(reply.answer(),reply.mode(),reply.notice(),reply.sources(),id,reply.tier(),reply.model());
    jdbc.update("INSERT INTO help_exchanges(id,user_id,cache_key,tier,mode,model,input_tokens,output_tokens,payload,expires_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
      id,user,key,reply.tier(),reply.mode(),reply.model(),input,output,encryption.encrypt(encode(new Stored(question,history,saved))),Timestamp.from(Instant.now().plusSeconds(days*86400L)));
    return saved;
  }
  @Transactional public void publish(long admin,Shared value) {
    String key=hash(normalize(value.question()));
    jdbc.update("DELETE FROM help_shared_answers WHERE question_key=?",key);
    jdbc.update("INSERT INTO help_shared_answers(question_key,knowledge_version,payload,approved_by,expires_at) VALUES (?,?,?,?,?)",
      key,version,encode(value),admin,Timestamp.from(Instant.now().plusSeconds(30*86400L)));
  }
  public void clearShared(){jdbc.update("DELETE FROM help_shared_answers");}
  public void clear(long user){jdbc.update("DELETE FROM help_exchanges WHERE user_id=?",user);}
  public void retain(long user,int days){
    if(days==0)clear(user);
    else jdbc.update("DELETE FROM help_exchanges WHERE user_id=? AND created_at<?",user,Timestamp.from(Instant.now().minusSeconds(days*86400L)));
  }
  @Scheduled(fixedDelay=3600000) public void purgeExpired(){
    jdbc.update("DELETE FROM help_exchanges WHERE expires_at<CURRENT_TIMESTAMP");
    jdbc.update("DELETE FROM help_shared_answers WHERE expires_at<CURRENT_TIMESTAMP");
  }
}
