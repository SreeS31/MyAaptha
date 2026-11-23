package com.myaaptha.domain.message;

import com.myaaptha.domain.circle.*;
import com.myaaptha.domain.circle.model.CircleEntity;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/network/chats/workspace") @Transactional
public class ChatWorkspaceController {
 public record Options(boolean favourite,boolean archived,Instant mutedUntil,String theme,String listName,int disappearingSeconds,boolean canManage,boolean creator,boolean solo){}
 public record Change(Boolean favourite,Boolean archived,@Min(0) @Max(2147483647) Integer muteSeconds,String theme,@Size(max=60) String listName,Integer disappearingSeconds){}
 public record Exit(Long successorId,Boolean deleteEmptyCircle){}
 private final JdbcTemplate db;private final CircleRepository circles;private final DirectMessageService direct;private final ChatRetentionService retention;
 public ChatWorkspaceController(JdbcTemplate db,CircleRepository circles,DirectMessageService direct,ChatRetentionService retention){this.db=db;this.circles=circles;this.direct=direct;this.retention=retention;}
 private long user(Principal p){return Long.parseLong(p.getName());}
 private CircleEntity access(long user,String kind,long target){
  if(kind.equals("DIRECT")){direct.validateRecipient(user,target);return null;}
  if(!kind.equals("CIRCLE"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose DIRECT or CIRCLE");
  var c=circles.findById(target).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Circle not found"));
  if(!c.getMemberUserIds().contains(user))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only circle members can access this chat");return c;
 }
 private long first(String kind,long user,long target){return kind.equals("DIRECT")?Math.min(user,target):target;}
 private long second(String kind,long user,long target){return kind.equals("DIRECT")?Math.max(user,target):0;}
 public record Summary(String kind,long targetId,boolean favourite,boolean archived,String listName){}
 @GetMapping public List<Summary> all(Principal p){return db.query("SELECT kind,target_id,favourite,archived,list_name FROM chat_workspace_options WHERE user_id=?",(rs,n)->new Summary(rs.getString(1),rs.getLong(2),rs.getBoolean(3),rs.getBoolean(4),rs.getString(5)),user(p));}
 @GetMapping("/{kind}/{target}") public Options get(Principal p,@PathVariable String kind,@PathVariable long target){long u=user(p);var c=access(u,kind,target);var rows=db.query("SELECT favourite,archived,muted_until,theme,list_name FROM chat_workspace_options WHERE user_id=? AND kind=? AND target_id=?",(rs,n)->new Options(rs.getBoolean(1),rs.getBoolean(2),rs.getTimestamp(3)==null?null:rs.getTimestamp(3).toInstant(),rs.getString(4),rs.getString(5),retention.seconds(kind,first(kind,u,target),second(kind,u,target)),c==null||c.getAdminUserIds().contains(u),c!=null&&Objects.equals(c.getOwnerUserId(),u),c!=null&&c.getMemberUserIds().size()==1),u,kind,target);return rows.isEmpty()?new Options(false,false,null,"DEFAULT","",retention.seconds(kind,first(kind,u,target),second(kind,u,target)),c==null||c.getAdminUserIds().contains(u),c!=null&&Objects.equals(c.getOwnerUserId(),u),c!=null&&c.getMemberUserIds().size()==1):rows.getFirst();}
 @PutMapping("/{kind}/{target}") public Options save(Principal p,@PathVariable String kind,@PathVariable long target,@Valid @RequestBody Change value){
  long u=user(p);if(kind.equals("DIRECT")){db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,Math.min(u,target));db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,Math.max(u,target));}else if(kind.equals("CIRCLE")){circles.findForUpdate(target).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Circle not found"));}var c=access(u,kind,target);var old=get(p,kind,target);
  if(value.theme()!=null&&!Set.of("DEFAULT","SAGE","OCEAN","ROSE","DARK").contains(value.theme()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose an available theme");
  if(value.disappearingSeconds()!=null){if(!old.canManage())throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only admins can change the circle timer");if(!Set.of(0,86400,604800,7776000).contains(value.disappearingSeconds()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose off, 24 hours, 7 days or 90 days");long a=first(kind,u,target),b=second(kind,u,target);db.update("DELETE FROM chat_message_retention WHERE kind=? AND first_id=? AND second_id=?",kind,a,b);db.update("INSERT INTO chat_message_retention(kind,first_id,second_id,seconds) VALUES(?,?,?,?)",kind,a,b,value.disappearingSeconds());}
  Instant muted=value.muteSeconds()==null?old.mutedUntil():value.muteSeconds()==0?null:Instant.now().plusSeconds(value.muteSeconds());
  db.update("DELETE FROM chat_workspace_options WHERE user_id=? AND kind=? AND target_id=?",u,kind,target);
  db.update("INSERT INTO chat_workspace_options(user_id,kind,target_id,favourite,archived,muted_until,theme,list_name) VALUES(?,?,?,?,?,?,?,?)",u,kind,target,value.favourite()==null?old.favourite():value.favourite(),value.archived()==null?old.archived():value.archived(),muted==null?null:java.sql.Timestamp.from(muted),value.theme()==null?old.theme():value.theme(),value.listName()==null?old.listName():value.listName().trim());
  return get(p,kind,target);
 }
 @DeleteMapping("/{kind}/{target}/history") public void clear(Principal p,@PathVariable String kind,@PathVariable long target){long u=user(p);access(u,kind,target);
  if(kind.equals("DIRECT")){db.update("UPDATE direct_messages SET sender_hidden=TRUE WHERE sender_user_id=? AND recipient_user_id=?",u,target);db.update("UPDATE direct_messages SET recipient_hidden=TRUE WHERE recipient_user_id=? AND sender_user_id=?",u,target);}
  else db.update("INSERT INTO circle_post_hidden(post_id,user_id) SELECT p.id,? FROM circle_posts p WHERE p.circle_id=? AND NOT EXISTS (SELECT 1 FROM circle_post_hidden h WHERE h.post_id=p.id AND h.user_id=?)",u,target,u);
 }
 @GetMapping("/{kind}/{target}/export") public List<Map<String,Object>> export(Principal p,@PathVariable String kind,@PathVariable long target,@RequestParam(defaultValue="9223372036854775807") long before){long u=user(p);access(u,kind,target);
  if(kind.equals("DIRECT"))return db.queryForList("SELECT id,sender_user_id AS authorId,message,attachment_name AS attachmentName,created_at AS createdAt FROM direct_messages WHERE id<? AND deleted_at IS NULL AND ((sender_user_id=? AND recipient_user_id=? AND sender_hidden=FALSE) OR (sender_user_id=? AND recipient_user_id=? AND recipient_hidden=FALSE)) ORDER BY id DESC LIMIT 500",before,u,target,target,u);
  return db.queryForList("SELECT p.id,p.author_user_id AS authorId,p.message,p.attachment_name AS attachmentName,p.created_at AS createdAt FROM circle_posts p WHERE p.circle_id=? AND p.id<? AND p.deleted_at IS NULL AND NOT EXISTS(SELECT 1 FROM circle_post_hidden h WHERE h.post_id=p.id AND h.user_id=?) ORDER BY p.id DESC LIMIT 500",target,before,u);
 }
 @PostMapping("/CIRCLE/{target}/exit") public void exit(Principal p,@PathVariable long target,@RequestBody Exit value){long u=user(p);db.queryForObject("SELECT id FROM circles WHERE id=? FOR UPDATE",Long.class,target);var c=access(u,"CIRCLE",target);
  if(Objects.equals(c.getOwnerUserId(),u)&&c.getMemberUserIds().size()==1){
   if(!Boolean.TRUE.equals(value.deleteEmptyCircle()))throw new ResponseStatusException(HttpStatus.CONFLICT,"Confirm removal of this circle because you are its only member");
   retention.removeCircleMedia(target);db.update("DELETE FROM communication_calls WHERE scope='CIRCLE' AND target_id=?",target);db.update("DELETE FROM chat_workspace_options WHERE kind='CIRCLE' AND target_id=?",target);db.update("DELETE FROM chat_message_retention WHERE kind='CIRCLE' AND first_id=?",target);circles.delete(c);return;
  }
  if(Objects.equals(c.getOwnerUserId(),u)){if(value.successorId()==null||value.successorId()==u||!c.getAdminUserIds().contains(value.successorId()))throw new ResponseStatusException(HttpStatus.CONFLICT,"Choose another active admin as the new creator before exiting");if(db.queryForObject("SELECT COUNT(*) FROM users WHERE id=? AND account_status='ACTIVE' AND identity_type<>'MANAGED'",Integer.class,value.successorId())!=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"Choose an active admin");c.setOwnerUserId(value.successorId());}
  c.getAdminUserIds().remove(u);c.getMemberUserIds().remove(u);circles.save(c);db.update("DELETE FROM chat_workspace_options WHERE user_id=? AND kind='CIRCLE' AND target_id=?",u,target);
  db.update("UPDATE communication_calls SET ended_at=CURRENT_TIMESTAMP WHERE scope='CIRCLE' AND target_id=? AND creator_user_id=? AND ended_at IS NULL",target,u);
  db.update("UPDATE communication_call_members SET status='LEFT' WHERE user_id=? AND call_id IN (SELECT id FROM communication_calls WHERE scope='CIRCLE' AND target_id=?)",u,target);
  db.update("DELETE FROM communication_call_signals WHERE call_id IN (SELECT id FROM communication_calls WHERE scope='CIRCLE' AND target_id=?) AND (sender_user_id=? OR recipient_user_id=?)",target,u,u);
 }
}
