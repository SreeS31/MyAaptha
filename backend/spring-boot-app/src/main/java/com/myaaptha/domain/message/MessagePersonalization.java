package com.myaaptha.domain.message;

import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class MessagePersonalization {
  public record Flags(boolean starred,boolean pinned) {}
  public static final Flags NONE=new Flags(false,false);
  private final JdbcTemplate jdbc;
  private final NamedParameterJdbcTemplate named;
  public MessagePersonalization(JdbcTemplate jdbc) { this.jdbc=jdbc;this.named=new NamedParameterJdbcTemplate(jdbc); }
  private void lock(Long owner) { jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner); }
  @Transactional(readOnly=true)
  public Map<Long,Flags> flags(Long owner,List<Long> ids) {
    if(ids.isEmpty())return Map.of();
    Map<Long,Flags> result=new HashMap<>();
    named.query("SELECT message_id,starred,pinned FROM direct_message_flags WHERE user_id=:owner AND message_id IN (:ids)",Map.of("owner",owner,"ids",ids),rs->{result.put(rs.getLong(1),new Flags(rs.getBoolean(2),rs.getBoolean(3)));});
    return result;
  }
  public void save(Long owner,Long message,Boolean star,Boolean pin) {
    lock(owner);var previous=flags(owner,List.of(message)).getOrDefault(message,NONE);
    boolean starred=star==null?previous.starred():star, pinned=pin==null?previous.pinned():pin;
    jdbc.update("DELETE FROM direct_message_flags WHERE user_id=? AND message_id=?",owner,message);
    if(starred||pinned)jdbc.update("INSERT INTO direct_message_flags(user_id,message_id,starred,pinned) VALUES (?,?,?,?)",owner,message,starred,pinned);
  }
  @Transactional(readOnly=true)
  public Set<Long> pinnedChats(Long owner) { return new HashSet<>(jdbc.queryForList("SELECT other_user_id FROM direct_chat_pins WHERE user_id=?",Long.class,owner)); }
  public void pinChat(Long owner,Long other,boolean pinned) {
    lock(owner);jdbc.update("DELETE FROM direct_chat_pins WHERE user_id=? AND other_user_id=?",owner,other);
    if(pinned)jdbc.update("INSERT INTO direct_chat_pins(user_id,other_user_id) VALUES (?,?)",owner,other);
  }
  public record ChatSettings(boolean archived, boolean muted, boolean markedUnread) {}
  public static final ChatSettings DEFAULT_CHAT = new ChatSettings(false, false, false);
  @Transactional(readOnly=true)
  public Map<Long,ChatSettings> chatSettings(Long owner) {
    Map<Long,ChatSettings> result = new HashMap<>();
    jdbc.query("SELECT other_user_id,archived,muted,marked_unread FROM direct_chat_settings WHERE user_id=?",
        rs -> { result.put(rs.getLong(1),new ChatSettings(rs.getBoolean(2),rs.getBoolean(3),rs.getBoolean(4))); },owner);
    return result;
  }
  @Transactional(readOnly=true)
  public boolean muted(Long owner,Long other) {
    return !jdbc.queryForList("SELECT other_user_id FROM direct_chat_settings WHERE user_id=? AND other_user_id=? AND muted=TRUE",Long.class,owner,other).isEmpty();
  }
  public void saveChatSettings(Long owner,Long other,Boolean archived,Boolean muted,Boolean markedUnread) {
    lock(owner);
    var old=chatSettings(owner).getOrDefault(other,DEFAULT_CHAT);
    jdbc.update("DELETE FROM direct_chat_settings WHERE user_id=? AND other_user_id=?",owner,other);
    jdbc.update("INSERT INTO direct_chat_settings(user_id,other_user_id,archived,muted,marked_unread) VALUES (?,?,?,?,?)",
        owner,other,archived==null?old.archived():archived,muted==null?old.muted():muted,markedUnread==null?old.markedUnread():markedUnread);
  }
  @Transactional(readOnly=true)
  public boolean readReceipts(Long owner) {
    var values=jdbc.queryForList("SELECT read_receipts FROM message_preferences WHERE user_id=?",Boolean.class,owner);
    return values.isEmpty()||values.getFirst();
  }
  @Transactional(readOnly=true)
  public boolean receiptsVisible(Collection<Long> participants) {
    return named.queryForObject("SELECT COUNT(*) FROM message_preferences WHERE user_id IN (:ids) AND read_receipts=FALSE",Map.of("ids",participants),Long.class)==0;
  }
  public void setReadReceipts(Long owner,boolean enabled) {
    lock(owner);jdbc.update("DELETE FROM message_preferences WHERE user_id=?",owner);
    jdbc.update("INSERT INTO message_preferences(user_id,read_receipts) VALUES (?,?)",owner,enabled);
  }
}
