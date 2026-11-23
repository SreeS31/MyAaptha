package com.myaaptha.domain.social;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
@Service public class SocialAudienceSettings {
 private final JdbcTemplate db;
 public SocialAudienceSettings(JdbcTemplate db){this.db=db;}
 public boolean closeFriend(long owner,long viewer){return db.queryForObject("SELECT COUNT(*) FROM social_close_friends WHERE owner_user_id=? AND member_user_id=?",Integer.class,owner,viewer)>0;}
}
