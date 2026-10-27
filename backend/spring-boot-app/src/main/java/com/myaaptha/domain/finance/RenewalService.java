package com.myaaptha.domain.finance;

import com.myaaptha.domain.notification.NotificationCommand;
import com.myaaptha.domain.notification.NotificationService;
import com.myaaptha.platform.media.MediaAssetService;
import com.myaaptha.platform.media.MediaObjectStorage;
import java.math.BigDecimal;
import java.sql.*;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class RenewalService {
  public static final List<Integer> REMINDER_DAYS = List.of(30,15,7,3,1);
  private final JdbcTemplate db;
  private final NotificationService notifications;
  private final MediaAssetService media;
  private final MediaObjectStorage storage;

  public RenewalService(JdbcTemplate db, NotificationService notifications, MediaAssetService media, MediaObjectStorage storage) {
    this.db=db;this.notifications=notifications;this.media=media;this.storage=storage;
  }
  public record Input(String kind,String title,String provider,String referenceNumber,BigDecimal amount,
      LocalDate purchasedOn,LocalDate expiresOn,String timezone,String notes,Boolean remindersEnabled,Boolean archived) {}
  public record Item(long id,String kind,String title,String provider,String referenceNumber,BigDecimal amount,
      LocalDate purchasedOn,LocalDate expiresOn,String timezone,String notes,boolean remindersEnabled,boolean archived,
      long daysRemaining,String status,Instant nextReminderAt,List<Integer> reminderDays,
      String attachmentUrl,String attachmentName,String attachmentType) {}
  private record Row(long id,long owner,Input input,int cycle,Instant next,String key,String name,String type) {}
  private final RowMapper<Row> mapper=(rs,n)->new Row(rs.getLong("id"),rs.getLong("user_id"),
      new Input(rs.getString("kind"),rs.getString("title"),rs.getString("provider"),rs.getString("reference_number"),
          rs.getBigDecimal("amount"),rs.getObject("purchased_on",LocalDate.class),rs.getObject("expires_on",LocalDate.class),
          rs.getString("timezone"),rs.getString("notes"),rs.getBoolean("reminders_enabled"),rs.getBoolean("archived")),
      rs.getInt("cycle"),rs.getTimestamp("next_reminder_at")==null?null:rs.getTimestamp("next_reminder_at").toInstant(),
      rs.getString("attachment_key"),rs.getString("attachment_name"),rs.getString("attachment_type"));

  @Transactional(readOnly=true)
  public List<Item> list(long owner) {
    return db.query("SELECT * FROM finance_renewals WHERE user_id=? ORDER BY archived, expires_on, id LIMIT 1000",mapper,owner)
        .stream().map(this::dto).toList();
  }
  @Transactional
  public Item create(long owner,Input input) {
    Input in=validate(input);Instant now=Instant.now();
    db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);
    if(db.queryForObject("SELECT COUNT(*) FROM finance_renewals WHERE user_id=?",Long.class,owner)>=1000)throw bad("You can keep up to 1000 bills and warranties; remove an older item first");
    Instant next=nextReminder(in,now,Set.of());
    var keys=new GeneratedKeyHolder();
    db.update(connection->{var ps=connection.prepareStatement("INSERT INTO finance_renewals (user_id,kind,title,provider,reference_number,amount,purchased_on,expires_on,timezone,notes,reminders_enabled,archived,next_reminder_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",new String[]{"id"});
      ps.setLong(1,owner);ps.setString(2,in.kind());ps.setString(3,in.title());ps.setString(4,in.provider());
      ps.setString(5,in.referenceNumber());ps.setBigDecimal(6,in.amount());ps.setObject(7,in.purchasedOn());ps.setObject(8,in.expiresOn());
      ps.setString(9,in.timezone());ps.setString(10,in.notes());ps.setBoolean(11,in.remindersEnabled());ps.setBoolean(12,in.archived());
      ps.setTimestamp(13,timestamp(next));return ps;},keys);
    return dto(owned(owner,Objects.requireNonNull(keys.getKey()).longValue(),false));
  }
  @Transactional
  public Item update(long owner,long id,Input input) {
    Input in=validate(input);Row old=owned(owner,id,true);
    int cycle=old.cycle()+(old.input().expiresOn().equals(in.expiresOn())?0:1);
    Instant next=nextReminder(in,Instant.now(),sent(id,cycle));
    db.update("UPDATE finance_renewals SET kind=?,title=?,provider=?,reference_number=?,amount=?,purchased_on=?,expires_on=?,timezone=?,notes=?,reminders_enabled=?,archived=?,cycle=?,next_reminder_at=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=?",
        in.kind(),in.title(),in.provider(),in.referenceNumber(),in.amount(),in.purchasedOn(),in.expiresOn(),in.timezone(),in.notes(),in.remindersEnabled(),in.archived(),cycle,timestamp(next),id,owner);
    if(cycle!=old.cycle()||!in.remindersEnabled()||in.archived())cancelQueued(id);
    return dto(owned(owner,id,false));
  }
  @Transactional
  public void delete(long owner,long id) {
    Row row=owned(owner,id,true);media.delete(row.key());cancelQueued(id);
    db.update("DELETE FROM finance_renewals WHERE id=? AND user_id=?",id,owner);
  }
  @Transactional
  public Item attach(long owner,long id,MultipartFile file) {
    Row row=owned(owner,id,true);
    var asset=media.store(owner,"FINANCE_RECEIPT",file,Set.of("application/pdf","image/jpeg","image/png","image/webp"),25*1024*1024,"finance/");
    media.delete(row.key());
    db.update("UPDATE finance_renewals SET attachment_key=?,attachment_name=?,attachment_type=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=?",asset.key(),asset.name(),asset.type(),id,owner);
    return dto(owned(owner,id,false));
  }
  @Transactional
  public void removeAttachment(long owner,long id) {
    Row row=owned(owner,id,true);media.delete(row.key());
    db.update("UPDATE finance_renewals SET attachment_key=NULL,attachment_name=NULL,attachment_type=NULL WHERE id=? AND user_id=?",id,owner);
  }
  public record Attachment(Resource resource,String name,String type) {}
  public record State(Boolean remindersEnabled,Boolean archived) {}
  @Transactional
  public Item state(long owner,long id,State state) {
    if(state==null||(state.remindersEnabled()==null&&state.archived()==null))throw bad("Choose a reminder or archive state");
    Input current=owned(owner,id,true).input();
    return update(owner,id,new Input(current.kind(),current.title(),current.provider(),current.referenceNumber(),current.amount(),current.purchasedOn(),current.expiresOn(),current.timezone(),current.notes(),
        state.remindersEnabled()==null?current.remindersEnabled():state.remindersEnabled(),state.archived()==null?current.archived():state.archived()));
  }
  @Transactional(readOnly=true)
  public Attachment attachment(long owner,long id) {
    Row row=owned(owner,id,false);if(row.key()==null)throw missing();
    media.assertAvailable(row.key());return new Attachment(storage.load(row.key()),row.name(),row.type());
  }
  public List<Long> due(Instant now) {
    return db.queryForList("SELECT id FROM finance_renewals WHERE next_reminder_at<=? AND reminders_enabled=TRUE AND archived=FALSE ORDER BY next_reminder_at,id LIMIT 100",Long.class,Timestamp.from(now));
  }
  /** Row lock plus receipt uniqueness atomically protect inbox/outbox across replicas. */
  @Transactional
  public void dispatch(long id,Instant now) {
    var rows=db.query("SELECT * FROM finance_renewals WHERE id=? FOR UPDATE SKIP LOCKED",mapper,id);
    if(rows.isEmpty())return;Row row=rows.getFirst();Input in=row.input();
    if(row.next()==null||row.next().isAfter(now)||!in.remindersEnabled()||in.archived())return;
    Set<Integer> sent=sent(id,row.cycle());
    long remaining=ChronoUnit.DAYS.between(now.atZone(ZoneId.of(in.timezone())).toLocalDate(),in.expiresOn());
    if(REMINDER_DAYS.contains((int)remaining)&&!sent.contains((int)remaining)) {
      var notice=notifications.notify(new NotificationCommand(row.owner(),"FINANCE_RENEWAL","Renewal reminder",
          in.title()+" "+("BILL".equals(in.kind())?"is due":"expires")+" in "+remaining+" day"+(remaining==1?"":"s")+" ("+in.expiresOn()+").",
          "/finance?renewal="+id+"#renewals","FINANCE_RENEWAL",id));
      if(notice!=null)db.update("INSERT INTO finance_renewal_notices (renewal_id,cycle,reminder_days,notification_id) VALUES (?,?,?,?)",id,row.cycle(),remaining,notice.id());
      sent.add((int)remaining);
    }
    db.update("UPDATE finance_renewals SET next_reminder_at=? WHERE id=?",timestamp(nextReminder(in,now.plusSeconds(1),sent)),id);
  }
  static Instant nextReminder(Input in,Instant now,Set<Integer> sent) {
    if(!in.remindersEnabled()||in.archived())return null;
    ZoneId zone=ZoneId.of(in.timezone());LocalDate today=now.atZone(zone).toLocalDate();
    for(int days:REMINDER_DAYS) {
      if(sent.contains(days))continue;
      LocalDate day=in.expiresOn().minusDays(days);
      if(day.isBefore(today))continue;
      Instant at=day.atTime(9,0).atZone(zone).toInstant();
      return at.isBefore(now)?now:at;
    }
    return null;
  }
  private Set<Integer> sent(long id,int cycle) {
    return new HashSet<>(db.queryForList("SELECT reminder_days FROM finance_renewal_notices WHERE renewal_id=? AND cycle=?",Integer.class,id,cycle));
  }
  private void cancelQueued(long id) {
    db.update("UPDATE notification_deliveries SET status='SKIPPED',last_error='Renewal updated or removed' WHERE status IN ('PENDING','RETRY') AND notification_id IN (SELECT id FROM notifications WHERE type='FINANCE_RENEWAL' AND entity_id=?)",id);
  }
  private Row owned(long owner,long id,boolean lock) {
    var rows=db.query("SELECT * FROM finance_renewals WHERE id=? AND user_id=?"+(lock?" FOR UPDATE":""),mapper,id,owner);
    if(rows.isEmpty())throw missing();return rows.getFirst();
  }
  private Item dto(Row row) {
    Input in=row.input();long days=ChronoUnit.DAYS.between(LocalDate.now(ZoneId.of(in.timezone())),in.expiresOn());
    return new Item(row.id(),in.kind(),in.title(),in.provider(),in.referenceNumber(),in.amount(),in.purchasedOn(),in.expiresOn(),in.timezone(),in.notes(),in.remindersEnabled(),in.archived(),days,
        in.archived()?"ARCHIVED":days<0?"EXPIRED":days==0?"DUE_TODAY":days<=30?"DUE_SOON":"ACTIVE",row.next(),REMINDER_DAYS,
        row.key()==null?null:"/api/finance/renewals/"+row.id()+"/attachment",row.name(),row.type());
  }
  private Input validate(Input input) {
    if(input==null)throw bad("Add bill or warranty details");
    String kind=clean(input.kind(),20),title=clean(input.title(),160),zone=clean(input.timezone(),80);
    if(!Set.of("BILL","WARRANTY","SERVICE").contains(kind==null?"":kind))throw bad("Choose bill, warranty or service");
    if(title==null)throw bad("A title is required");
    if(input.expiresOn()==null||input.expiresOn().getYear()<1900||input.expiresOn().getYear()>9999)throw bad("Choose a valid expiry or due date");
    if(input.purchasedOn()!=null&&(input.purchasedOn().getYear()<1900||input.purchasedOn().isAfter(input.expiresOn())))throw bad("Purchase date must be on or before expiry");
    if(input.amount()!=null&&(input.amount().signum()<0||input.amount().compareTo(new BigDecimal("1000000000000"))>0||input.amount().scale()>2))throw bad("Amount must be between 0 and 1000000000000 with at most two decimal places");
    if(zone==null)zone="Asia/Kolkata";
    try{ZoneId.of(zone);}catch(DateTimeException e){throw bad("Choose a valid time zone");}
    return new Input(kind,title,clean(input.provider(),160),clean(input.referenceNumber(),160),input.amount(),input.purchasedOn(),input.expiresOn(),zone,clean(input.notes(),2000),!Boolean.FALSE.equals(input.remindersEnabled()),Boolean.TRUE.equals(input.archived()));
  }
  private static String clean(String value,int limit){if(value==null||value.isBlank())return null;String v=value.trim();if(v.length()>limit)throw bad("A field exceeds its allowed length");return v;}
  private static Timestamp timestamp(Instant value){return value==null?null:Timestamp.from(value);}
  private static ResponseStatusException bad(String message){return new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
  private static ResponseStatusException missing(){return new ResponseStatusException(HttpStatus.NOT_FOUND,"Bill or warranty not found");}
}
