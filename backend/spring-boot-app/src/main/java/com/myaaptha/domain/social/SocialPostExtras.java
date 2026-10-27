package com.myaaptha.domain.social;

import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SocialPostExtras {
  private final JdbcTemplate db;
  public SocialPostExtras(JdbcTemplate db){this.db=db;}
  public Map<String,Long> reactions(long post){
    Map<String,Long> result=new LinkedHashMap<>();
    db.query("select reaction,count(*) as total from social_post_likes where post_id=? group by reaction order by total desc,reaction",r->{result.put(r.getString(1),r.getLong(2));},post);
    return result;
  }
  public String reaction(long post,long user){return db.query("select reaction from social_post_likes where post_id=? and user_id=?",(r,n)->r.getString(1),post,user).stream().findFirst().orElse(null);}
  // Caller holds the social-post row lock for every mutation of likes or flags.
  public void react(long post,long user,String emoji){
    if(emoji==null){db.update("delete from social_post_likes where post_id=? and user_id=?",post,user);return;}
    if(db.update("update social_post_likes set reaction=? where post_id=? and user_id=?",emoji,post,user)==0)db.update("insert into social_post_likes(post_id,user_id,reaction) values(?,?,?)",post,user,emoji);
  }
  public boolean pinned(long post,long user){return Boolean.TRUE.equals(db.queryForObject("select count(*)>0 from social_post_flags where post_id=? and user_id=? and pinned=true",Boolean.class,post,user));}
  public void pin(long post,long user,boolean pinned){db.update("delete from social_post_flags where post_id=? and user_id=?",post,user);if(pinned)db.update("insert into social_post_flags(post_id,user_id,pinned) values(?,?,true)",post,user);}
}
