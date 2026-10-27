package com.myaaptha.domain.timeline;
import java.security.Principal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/timeline/events")
public class TimelineController {
 private final JdbcTemplate db;
 public TimelineController(JdbcTemplate db){this.db=db;}
 public record Event(String eventKey,String date,String kind,String title,String detail){}
 @GetMapping public List<Event> list(Principal principal){return db.query("SELECT event_key,event_date,kind,title,detail FROM timeline_events WHERE user_id=? ORDER BY event_date DESC,event_key",(r,i)->new Event(r.getString(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5)),Long.valueOf(principal.getName()));}
 @DeleteMapping("/{key}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional
 public void remove(Principal principal,@PathVariable String key){
  if(!key.matches("[A-Za-z0-9_-]{1,100}"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use a valid event key.");
  // Serialize owner mutations, including empty timelines, against quota checks and new-key saves.
  lock(Long.valueOf(principal.getName()));
  // Only saved events / overrides are removed. Derived profile and relationship data stays intact.
  db.update("DELETE FROM timeline_events WHERE user_id=? AND event_key=?",Long.valueOf(principal.getName()),key);
 }
 @PutMapping("/{key}") @Transactional public Event save(Principal principal,@PathVariable String key,@RequestBody Event input){
  if(!key.matches("[A-Za-z0-9_-]{1,100}")||input.date()==null||input.title()==null||input.title().isBlank()||input.title().length()>200||input.detail()!=null&&input.detail().length()>2000||!Set.of("Birth","Family","Remembrance","Education","Marriage","Employment","Other").contains(input.kind()==null?"":input.kind()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a valid event type, date and title (maximum 200 characters).");
  try{LocalDate.parse(input.date());}catch(Exception e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use a valid event date.");}
  Long owner=Long.valueOf(principal.getName());lock(owner);String detail=input.detail()==null?"":input.detail().trim();String title=input.title().trim();
  int changed=db.update("UPDATE timeline_events SET event_date=?,kind=?,title=?,detail=? WHERE user_id=? AND event_key=?",input.date(),input.kind(),title,detail,owner,key);
  if(changed==0){if(db.queryForObject("SELECT COUNT(*) FROM timeline_events WHERE user_id=?",Long.class,owner)>=500)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Maximum 500 timeline events.");db.update("INSERT INTO timeline_events(user_id,event_key,event_date,kind,title,detail) VALUES(?,?,?,?,?,?)",owner,key,input.date(),input.kind(),title,detail);}
  return new Event(key,input.date(),input.kind(),title,detail);
 }
 private void lock(Long owner){db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);}
}
