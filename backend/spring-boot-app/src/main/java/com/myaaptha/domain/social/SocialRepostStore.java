package com.myaaptha.domain.social;
import java.time.Instant;import java.util.List;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.stereotype.Component;
@Component public class SocialRepostStore{
 public record Stats(long count,boolean mine){}
 public record Entry(long postId,long userId,Instant createdAt){}
 private final JdbcTemplate db;public SocialRepostStore(JdbcTemplate db){this.db=db;}
 public Stats stats(long post,long viewer){return db.queryForObject("SELECT COUNT(*),COALESCE(SUM(CASE WHEN user_id=? THEN 1 ELSE 0 END),0) FROM social_reposts WHERE post_id=?",(rs,n)->new Stats(rs.getLong(1),rs.getLong(2)>0),viewer,post);}
 public void set(long post,long user,boolean reposted){if(!reposted){db.update("DELETE FROM social_reposts WHERE post_id=? AND user_id=?",post,user);return;}if(db.queryForObject("SELECT COUNT(*) FROM social_reposts WHERE post_id=? AND user_id=?",Long.class,post,user)==0)db.update("INSERT INTO social_reposts(post_id,user_id) VALUES(?,?)",post,user);}
 public List<Entry> latest(){return db.query("SELECT r.post_id,r.user_id,r.created_at FROM social_reposts r JOIN users u ON u.id=r.user_id WHERE u.account_status='ACTIVE' ORDER BY r.created_at DESC,r.id DESC LIMIT 100",(rs,n)->new Entry(rs.getLong(1),rs.getLong(2),rs.getTimestamp(3).toInstant()));}
}
