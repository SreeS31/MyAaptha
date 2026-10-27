package com.myaaptha.platform.security;

import com.myaaptha.platform.state.EphemeralState;
import jakarta.servlet.http.HttpServletRequest;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import org.springframework.web.context.request.*;
import org.springframework.web.servlet.HandlerMapping;

@Service
public class SecurityIncidentService {
 private final JdbcTemplate jdbc; private final EphemeralState state;
 public SecurityIncidentService(JdbcTemplate jdbc,EphemeralState state){this.jdbc=jdbc;this.state=state;}
 @org.springframework.context.event.EventListener(org.springframework.boot.context.event.ApplicationReadyEvent.class)
 public void restoreBlocks(){jdbc.query("SELECT ip_address,MAX(blocked_until) AS expiry FROM security_incidents WHERE blocked_until>? GROUP BY ip_address",(org.springframework.jdbc.core.RowCallbackHandler)row->{var ttl=Duration.between(Instant.now(),row.getTimestamp("expiry").toInstant());if(!ttl.isNegative()&&!ttl.isZero())state.put("security:block:"+row.getString("ip_address"),"malware",ttl);},Timestamp.from(Instant.now()));}
 @org.springframework.scheduling.annotation.Scheduled(fixedDelay=3600000) @Transactional
 public void retention(){jdbc.update("DELETE FROM security_incidents WHERE occurred_at<? AND (blocked_until IS NULL OR blocked_until<?)",Timestamp.from(Instant.now().minus(Duration.ofDays(90))),Timestamp.from(Instant.now()));}
 public boolean blocked(String ip){return state.get("security:block:"+ip)!=null;}
 @Transactional(propagation=Propagation.REQUIRES_NEW)
 public void record(String category,String summary,boolean block){
  var context=RequestContextHolder.getRequestAttributes();
  HttpServletRequest request=context instanceof ServletRequestAttributes attributes?attributes.getRequest():null;
  recordRequest(request,category,summary,block);
 }
 @Transactional(propagation=Propagation.REQUIRES_NEW)
 public void recordRequest(HttpServletRequest request,String category,String summary,boolean block){
  String ip=request==null?"unknown":request.getRemoteAddr();
  Instant now=Instant.now(),until=block?now.plus(Duration.ofHours(1)):null;
  if(block)state.put("security:block:"+ip,"malware",Duration.ofHours(1));
  // Deduplicate bursts, keeping the report and alert queue bounded during attacks.
  if(state.increment("security:event:"+ip+":"+category,Duration.ofMinutes(5))>1)return;
  String actor=request!=null&&request.getUserPrincipal()!=null?request.getUserPrincipal().getName():null;
  Object pattern=request==null?null:request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
  String path=pattern==null?"API request":pattern.toString();
  jdbc.update("INSERT INTO security_incidents(occurred_at,category,summary,request_path,ip_address,actor,blocked_until,email_next_attempt) VALUES (?,?,?,?,?,?,?,?)",Timestamp.from(now),category,summary,path,ip,actor,until==null?null:Timestamp.from(until),Timestamp.from(now));
 }
 public record Incident(long id,Instant occurredAt,String category,String summary,String requestPath,String ipAddress,String actor,Instant blockedUntil,Instant resolvedAt,String emailStatus){}
 public List<Incident> list(int page){return jdbc.query("SELECT * FROM security_incidents ORDER BY id DESC LIMIT 50 OFFSET ?",(r,n)->new Incident(r.getLong("id"),r.getTimestamp("occurred_at").toInstant(),r.getString("category"),r.getString("summary"),r.getString("request_path"),r.getString("ip_address"),r.getString("actor"),r.getTimestamp("blocked_until")==null?null:r.getTimestamp("blocked_until").toInstant(),r.getTimestamp("resolved_at")==null?null:r.getTimestamp("resolved_at").toInstant(),r.getString("email_status")),Math.max(0,Math.min(page,10000))*50);}
 @Transactional public void resolve(long id){jdbc.update("UPDATE security_incidents SET resolved_at=? WHERE id=?",Timestamp.from(Instant.now()),id);}
 @Transactional public void unblock(long id){var ips=jdbc.queryForList("SELECT ip_address FROM security_incidents WHERE id=?",String.class,id);if(ips.isEmpty())return;state.delete("security:block:"+ips.getFirst());jdbc.update("UPDATE security_incidents SET blocked_until=? WHERE ip_address=? AND blocked_until>?",Timestamp.from(Instant.now()),ips.getFirst(),Timestamp.from(Instant.now()));}
}
