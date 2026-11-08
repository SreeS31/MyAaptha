package com.myaaptha.platform.media;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

@Service
public class UploadPolicyService {
  private final JdbcTemplate db;
  public UploadPolicyService(JdbcTemplate db){this.db=db;}
  public static final List<Integer> RETENTION_DAYS=List.of(1,7,30,60,90,180,365,730,1095,1825,3650,0);
  public record Level(int id,String name,long storageBytes,long uploadBytes,int maxRetentionDays,boolean allowNever){}
  private final org.springframework.jdbc.core.RowMapper<Level> mapper=(rs,n)->new Level(rs.getInt("id"),rs.getString("name"),rs.getLong("storage_bytes"),rs.getLong("upload_bytes"),rs.getInt("max_retention_days"),rs.getBoolean("allow_never"));
  public List<Level> levels(){return db.query("SELECT * FROM upload_levels ORDER BY id",mapper);}
  public Level policy(long owner){return db.queryForObject("SELECT l.* FROM upload_levels l JOIN users u ON u.upload_level_id=l.id WHERE u.id=?",mapper,owner);}
  // The user row serializes quota checks with every concurrent upload and level assignment.
  public Level lockPolicy(long owner){db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);return policy(owner);}
  @Transactional public Level save(Level level){
    if(level.id()<1||level.id()>5||level.name()==null||level.name().trim().isEmpty()||level.name().trim().length()>50||level.storageBytes()<0||level.storageBytes()>107374182400L||level.uploadBytes()<1||level.uploadBytes()>26214400L||!level.allowNever()||level.maxRetentionDays()<1||level.maxRetentionDays()>36500)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use levels 1-5, storage up to 100 GB, uploads up to 25 MB and never-expiring active files.");
    // Serialize creation as well as edits across API instances.
    db.queryForObject("SELECT id FROM upload_levels WHERE id=1 FOR UPDATE",Integer.class);
    int changed=db.update("UPDATE upload_levels SET name=?,storage_bytes=?,upload_bytes=?,max_retention_days=?,allow_never=? WHERE id=?",level.name().trim(),level.storageBytes(),level.uploadBytes(),3650,true,level.id());
    if(changed==0)db.update("INSERT INTO upload_levels VALUES (?,?,?,?,?,?)",level.id(),level.name().trim(),level.storageBytes(),level.uploadBytes(),3650,true);
    return levels().stream().filter(v->v.id()==level.id()).findFirst().orElseThrow();
  }
  @Transactional public void assign(long userId,int levelId){
    if(levels().stream().noneMatch(l->l.id()==levelId))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose an existing level");
    if(db.update("UPDATE users SET upload_level_id=? WHERE id=?",levelId,userId)!=1)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"User not found");
  }
  public Instant expiry(Level level){
    var attributes=RequestContextHolder.getRequestAttributes();
    String value=null;boolean status=false;
    if(attributes instanceof ServletRequestAttributes a){
      value=a.getRequest().getParameter("retentionDays");
      status=a.getRequest().getRequestURI().matches(".*/stories/?$");
    }
    if(status)return Instant.now().plus(1,ChronoUnit.DAYS);
    int days=0;
    if(value!=null&&!value.isBlank())try{days=Integer.parseInt(value);}catch(NumberFormatException e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a listed expiry period or Never");}
    if(!RETENTION_DAYS.contains(days))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose 1, 7, 30, 60, 90, 180, 365, 730, 1095, 1825 or 3650 days, or Never (0)");
    return days==0?null:Instant.now().plus(days,ChronoUnit.DAYS);
  }
}
