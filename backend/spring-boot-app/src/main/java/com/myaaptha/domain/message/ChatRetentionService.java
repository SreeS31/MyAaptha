package com.myaaptha.domain.message;

import java.time.Instant;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.scheduling.annotation.Scheduled;
import com.myaaptha.domain.circle.CircleMediaStorage;

@Service
public class ChatRetentionService {
 private final JdbcTemplate db; private final CircleMediaStorage storage;
 public ChatRetentionService(JdbcTemplate db,CircleMediaStorage storage){this.db=db;this.storage=storage;}
 @Transactional public void removeCircleMedia(long circle){for(String key:db.queryForList("SELECT attachment_key FROM circle_posts WHERE circle_id=? AND attachment_key IS NOT NULL",String.class,circle))storage.delete(key);db.update("DELETE FROM chat_message_expiry WHERE kind='CIRCLE' AND message_id IN (SELECT id FROM circle_posts WHERE circle_id=?)",circle);}
 public boolean muted(long user,String kind,long target){return db.queryForObject("SELECT COUNT(*) FROM chat_workspace_options WHERE user_id=? AND kind=? AND target_id=? AND muted_until>CURRENT_TIMESTAMP",Integer.class,user,kind,target)>0;}
 public int seconds(String kind,long first,long second){var values=db.queryForList("SELECT seconds FROM chat_message_retention WHERE kind=? AND first_id=? AND second_id=?",Integer.class,kind,first,second);return values.isEmpty()?0:values.getFirst();}
 @Transactional public void register(String kind,long sender,long target,long message){long first=kind.equals("DIRECT")?Math.min(sender,target):target, second=kind.equals("DIRECT")?Math.max(sender,target):0;int seconds=seconds(kind,first,second);if(seconds>0)db.update("INSERT INTO chat_message_expiry(kind,message_id,expires_at) VALUES(?,?,?)",kind,message,java.sql.Timestamp.from(Instant.now().plusSeconds(seconds)));}
 // New messages only. Expiry is processed at most a minute after the timer elapses.
 @Scheduled(fixedDelay=60000) @Transactional public void expire(){
  var due=db.queryForList("SELECT kind,message_id FROM chat_message_expiry WHERE expires_at<=CURRENT_TIMESTAMP ORDER BY expires_at LIMIT 200");
  for(var row:due){String kind=(String)row.get("kind"),table=kind.equals("DIRECT")?"direct_messages":"circle_posts";long id=((Number)row.get("message_id")).longValue();
   var keys=db.queryForList("SELECT attachment_key FROM "+table+" WHERE id=? FOR UPDATE",String.class,id);for(String key:keys)if(key!=null)storage.delete(key);
   db.update("UPDATE "+table+" SET message='',attachment_key=NULL,attachment_name=NULL,attachment_type=NULL,attachment_size=NULL,deleted_at=CURRENT_TIMESTAMP WHERE id=?",id);
   db.update("UPDATE notifications SET body='Message expired' WHERE entity_type=? AND entity_id=?",kind.equals("DIRECT")?"DIRECT_MESSAGE":"CIRCLE_POST",id);
   db.update("DELETE FROM chat_message_expiry WHERE kind=? AND message_id=?",kind,id);
  }
 }
}
