package com.myaaptha.domain.message;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.privacy.UserBlockRepository;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service @Transactional
public class CommunicationCallService {
  public record Member(long userId,String name,String status) {}
  public record Room(String id,String scope,long targetId,long creatorId,String name,String callType,String createdAt,boolean ended,long currentUserId,List<Member> members,int capacity) {}
  public record Envelope(long id,long senderId,String type,String payload) {}
  private record Row(String id,String scope,long target,long creator,String type,Instant created,boolean ended) {}
  private final com.fasterxml.jackson.databind.ObjectMapper json;private final JdbcTemplate db;private final CircleRepository circles;private final UserRepository users;private final DirectMessageService direct;private final UserBlockRepository blocks;
  public CommunicationCallService(com.fasterxml.jackson.databind.ObjectMapper json,JdbcTemplate db,CircleRepository circles,UserRepository users,DirectMessageService direct,UserBlockRepository blocks){this.json=json;this.db=db;this.circles=circles;this.users=users;this.direct=direct;this.blocks=blocks;}
  private ResponseStatusException error(HttpStatus status,String message){return new ResponseStatusException(status,message);}
  private Row row(String id,boolean lock){
    var rows=db.query("SELECT * FROM communication_calls WHERE id=?"+(lock?" FOR UPDATE":""),(r,n)->new Row(r.getString("id"),r.getString("scope"),r.getLong("target_id"),r.getLong("creator_user_id"),r.getString("call_type"),r.getTimestamp("created_at").toInstant(),r.getTimestamp("ended_at")!=null),id);
    if(rows.isEmpty())throw error(HttpStatus.NOT_FOUND,"Call not found");return rows.getFirst();
  }
  private void access(long user,Row call){
    if(call.scope.equals("CIRCLE")){
      var circle=circles.findById(call.target).orElseThrow(()->error(HttpStatus.NOT_FOUND,"Circle not found"));
      if(!circle.getMemberUserIds().contains(user))throw error(HttpStatus.FORBIDDEN,"Only circle members can join this call");
    }else if(user!=call.creator&&user!=call.target)throw error(HttpStatus.FORBIDDEN,"Only call participants can access this call");
    if(user!=call.creator&&blocks.blockedEitherWay(user,call.creator))throw error(HttpStatus.FORBIDDEN,"Calling is unavailable for this account");
  }
  private boolean live(Row call){return !call.ended&&call.created.isAfter(Instant.now().minusSeconds(7200))&&db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=? AND status='JOINED' AND last_seen>?",Integer.class,call.id,Timestamp.from(Instant.now().minusSeconds(90)))>0;}
  private void requireLive(Row call){if(!live(call))throw error(HttpStatus.CONFLICT,"This call has ended");}
  private void joined(long user,Row call){access(user,call);requireLive(call);if(db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=? AND user_id=? AND status='JOINED'",Integer.class,call.id,user)==0)throw error(HttpStatus.FORBIDDEN,"Join the call before exchanging connection information");}
  private Room dto(long user,Row call){
    String name=call.scope.equals("CIRCLE")?circles.findById(call.target).orElseThrow().getName():name(user==call.creator?call.target:call.creator);
    var members=db.query("SELECT user_id,status FROM communication_call_members WHERE call_id=? AND (status='JOINED' OR user_id=?) ORDER BY user_id",(r,n)->new Member(r.getLong(1),name(r.getLong(1)),r.getString(2)),call.id,user);
    return new Room(call.id,call.scope,call.target,call.creator,name,call.type,call.created.toString(),!live(call),user,members,call.scope.equals("DIRECT")?2:8);
  }
  private String name(long id){return users.findById(id).map(u->{String value=((u.getFirstName()==null?"":u.getFirstName())+" "+(u.getSurname()==null?"":u.getSurname())).trim();return value.isEmpty()?u.getUsername():value;}).orElse("Member");}
  public Room start(long user,CommunicationCallController.Start input){
    if(input.scope().equals("DIRECT")){
      if(user==input.targetId())throw error(HttpStatus.BAD_REQUEST,"Choose another person to call");
      boolean prior=db.queryForObject("SELECT COUNT(*) FROM communication_calls WHERE scope='DIRECT' AND ((creator_user_id=? AND target_id=?) OR (creator_user_id=? AND target_id=?))",Integer.class,user,input.targetId(),input.targetId(),user)>0;
      if(prior){
        if(blocks.blockedEitherWay(user,input.targetId()))throw error(HttpStatus.FORBIDDEN,"Calling is unavailable for this account");
        var recipient=users.findById(input.targetId()).orElseThrow(()->error(HttpStatus.NOT_FOUND,"Person not found"));
        if(!"ACTIVE".equals(recipient.getAccountStatus())||"MANAGED".equals(recipient.getIdentityType()))throw error(HttpStatus.BAD_REQUEST,"This person cannot receive calls");
      }else direct.validateRecipient(user,input.targetId());
      db.queryForList("SELECT id FROM users WHERE id IN (?,?) ORDER BY id FOR UPDATE",user,input.targetId());
    }
    else {
      // Serialize starts within a circle so concurrent callers find the same live room.
      db.queryForList("SELECT id FROM circles WHERE id=? FOR UPDATE",input.targetId());
      access(user,new Row("",input.scope(),input.targetId(),user,input.callType(),Instant.now(),false));
    }
    var existing=input.scope().equals("DIRECT")?db.queryForList("SELECT id FROM communication_calls WHERE scope='DIRECT' AND ((creator_user_id=? AND target_id=?) OR (creator_user_id=? AND target_id=?)) AND ended_at IS NULL ORDER BY created_at DESC LIMIT 20",String.class,user,input.targetId(),input.targetId(),user):db.queryForList("SELECT id FROM communication_calls WHERE scope=? AND target_id=? AND ended_at IS NULL ORDER BY created_at DESC LIMIT 20",String.class,input.scope(),input.targetId());
    for(String id:existing){var call=row(id,false);if(live(call)){access(user,call);return dto(user,call);}}
    if(db.queryForObject("SELECT COUNT(*) FROM communication_calls WHERE creator_user_id=? AND ended_at IS NULL AND created_at>?",Integer.class,user,Timestamp.from(Instant.now().minusSeconds(90)))>=5)throw error(HttpStatus.TOO_MANY_REQUESTS,"Please wait before starting another call");
    db.update("DELETE FROM communication_calls WHERE created_at<?",Timestamp.from(Instant.now().minusSeconds(604800)));
    String id=UUID.randomUUID().toString();db.update("INSERT INTO communication_calls(id,scope,target_id,creator_user_id,call_type) VALUES (?,?,?,?,?)",id,input.scope(),input.targetId(),user,input.callType());
    db.update("INSERT INTO communication_call_members(call_id,user_id,status) VALUES (?,?,'JOINED')",id,user);
    if(input.scope().equals("DIRECT"))db.update("INSERT INTO communication_call_members(call_id,user_id,status) VALUES (?,?,'INVITED')",id,input.targetId());
    return dto(user,row(id,false));
  }
  public List<Room> active(long user){return rooms(user,false);}
  public List<Room> history(long user){return rooms(user,true);}
  private List<Room> rooms(long user,boolean history){
    var ids=db.queryForList("SELECT DISTINCT c.id,c.created_at FROM communication_calls c LEFT JOIN circle_members m ON c.scope='CIRCLE' AND m.circle_id=c.target_id WHERE "+(history?"":"c.ended_at IS NULL AND ")+"c.created_at>? AND ((c.scope='DIRECT' AND (c.creator_user_id=? OR c.target_id=?)) OR (c.scope='CIRCLE' AND m.user_id=?)) ORDER BY c.created_at DESC LIMIT 100",Timestamp.from(Instant.now().minusSeconds(history?604800:7200)),user,user,user);
    var result=new ArrayList<Room>();for(var value:ids){var call=row((String)value.get("id"),false);try{access(user,call);var statuses=db.queryForList("SELECT status FROM communication_call_members WHERE call_id=? AND user_id=?",String.class,call.id,user);if(history||(live(call)&&(statuses.isEmpty()||!Set.of("LEFT","DECLINED").contains(statuses.getFirst()))))result.add(dto(user,call));}catch(ResponseStatusException ignored){/* Membership was revoked or an account was blocked. */}}return result;
  }
  public Room get(long user,String id){var call=row(id,false);access(user,call);if(!live(call))return dto(user,call);db.update("UPDATE communication_call_members SET status='LEFT' WHERE call_id=? AND status='JOINED' AND last_seen<?",id,Timestamp.from(Instant.now().minusSeconds(90)));db.update("UPDATE communication_call_members SET last_seen=CURRENT_TIMESTAMP WHERE call_id=? AND user_id=? AND status='JOINED'",id,user);return dto(user,call);}
  public Room join(long user,String id){var call=row(id,true);access(user,call);requireLive(call);
    db.update("UPDATE communication_call_members SET status='LEFT' WHERE call_id=? AND status='JOINED' AND last_seen<?",id,Timestamp.from(Instant.now().minusSeconds(90)));
    boolean already=db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=? AND user_id=? AND status='JOINED'",Integer.class,id,user)>0;
    if(!already&&db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=? AND status='JOINED'",Integer.class,id)>=8)throw error(HttpStatus.CONFLICT,"This call is full (8 participants)");
    if(db.update("UPDATE communication_call_members SET status='JOINED',last_seen=CURRENT_TIMESTAMP WHERE call_id=? AND user_id=?",id,user)==0)db.update("INSERT INTO communication_call_members(call_id,user_id,status) VALUES (?,?,'JOINED')",id,user);
    return dto(user,row(id,false));
  }
  public void leave(long user,String id){var call=row(id,true);access(user,call);if(db.update("UPDATE communication_call_members SET status=CASE WHEN status='INVITED' THEN 'DECLINED' ELSE 'LEFT' END WHERE call_id=? AND user_id=?",id,user)==0&&call.scope.equals("CIRCLE"))db.update("INSERT INTO communication_call_members(call_id,user_id,status) VALUES (?,?,'DECLINED')",id,user);
    if(db.queryForObject("SELECT COUNT(*) FROM communication_call_members WHERE call_id=? AND status='JOINED'",Integer.class,id)==0||call.scope.equals("DIRECT"))db.update("UPDATE communication_calls SET ended_at=CURRENT_TIMESTAMP WHERE id=?",id);
    db.update("DELETE FROM communication_call_signals WHERE call_id=? AND (sender_user_id=? OR recipient_user_id=?)",id,user,user);
  }
  public void end(long user,String id){var call=row(id,true);access(user,call);if(user!=call.creator&&call.scope.equals("CIRCLE"))throw error(HttpStatus.FORBIDDEN,"Only the caller can end the circle call for everyone");db.update("UPDATE communication_calls SET ended_at=CURRENT_TIMESTAMP WHERE id=?",id);db.update("DELETE FROM communication_call_signals WHERE call_id=?",id);}
  public void signal(long user,String id,CommunicationCallController.Signal signal){try{var value=json.readTree(signal.payload());if(!value.isObject()||(signal.type().equals("ice")?!value.path("candidate").isTextual():!value.path("sdp").isTextual()||!signal.type().equals(value.path("type").asText())))throw new IllegalArgumentException();}catch(Exception exception){throw error(HttpStatus.BAD_REQUEST,"Invalid call connection information");}var call=row(id,false);joined(user,call);if(signal.recipientId()==user)throw error(HttpStatus.BAD_REQUEST,"Choose another participant");joined(signal.recipientId(),call);db.update("DELETE FROM communication_call_signals WHERE call_id=? AND created_at<?",id,Timestamp.from(Instant.now().minusSeconds(300)));if(db.queryForObject("SELECT COUNT(*) FROM communication_call_signals WHERE call_id=?",Integer.class,id)>=4096)throw error(HttpStatus.TOO_MANY_REQUESTS,"Call connection queue is full");db.update("INSERT INTO communication_call_signals(call_id,sender_user_id,recipient_user_id,signal_type,payload) VALUES (?,?,?,?,?)",id,user,signal.recipientId(),signal.type(),signal.payload());}
  public List<Envelope> signals(long user,String id,long after){var call=row(id,false);joined(user,call);return db.query("SELECT id,sender_user_id,signal_type,payload FROM communication_call_signals WHERE call_id=? AND recipient_user_id=? AND id>? ORDER BY id LIMIT 100",(r,n)->new Envelope(r.getLong(1),r.getLong(2),r.getString(3),r.getString(4)),id,user,after);}
  @org.springframework.scheduling.annotation.Scheduled(fixedDelay=60000,initialDelay=60000)
  public void purgeExpiredSignaling(){
    db.update("DELETE FROM communication_call_signals WHERE created_at<?",Timestamp.from(Instant.now().minusSeconds(300)));
    db.update("UPDATE communication_calls SET ended_at=CURRENT_TIMESTAMP WHERE ended_at IS NULL AND (created_at<? OR NOT EXISTS (SELECT 1 FROM communication_call_members m WHERE m.call_id=communication_calls.id AND m.status='JOINED' AND m.last_seen>?))",Timestamp.from(Instant.now().minusSeconds(7200)),Timestamp.from(Instant.now().minusSeconds(90)));
    db.update("DELETE FROM communication_calls WHERE created_at<?",Timestamp.from(Instant.now().minusSeconds(604800)));
  }
}
