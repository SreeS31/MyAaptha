package com.myaaptha.domain.circle;

import java.sql.SQLException;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.*;

@Component
public class CircleReadWriter {
  private final JdbcTemplate jdbc;
  private final String sql;
  private final boolean postgres;
  public CircleReadWriter(JdbcTemplate jdbc,DataSource source)throws SQLException{
    this.jdbc=jdbc;
    try(var connection=source.getConnection()){
      postgres=connection.getMetaData().getDatabaseProductName().equals("PostgreSQL");
      sql=postgres
        ?"INSERT INTO circle_post_reads(post_id,user_id,read_at) VALUES (?,?,CURRENT_TIMESTAMP) ON CONFLICT (post_id,user_id) DO NOTHING"
        :"MERGE INTO circle_post_reads(post_id,user_id,read_at) KEY(post_id,user_id) VALUES (?,?,CURRENT_TIMESTAMP)";
    }
  }
  @Transactional(propagation=Propagation.MANDATORY)
  public void markRead(Long userId,List<Long> postIds){
    if(postIds.isEmpty())return;
    if(postgres){
      // Polling an already-read page must not reissue one insert per message.
      // Keep ON CONFLICT for concurrent requests racing after the NOT EXISTS check.
      for(int offset=0;offset<postIds.size();offset+=100){
        var page=postIds.subList(offset,Math.min(offset+100,postIds.size()));
        var placeholders=String.join(",",java.util.Collections.nCopies(page.size(),"?"));
        var statement="INSERT INTO circle_post_reads(post_id,user_id,read_at) "
          +"SELECT p.id,?,CURRENT_TIMESTAMP FROM circle_posts p WHERE p.id IN ("+placeholders+") "
          +"AND NOT EXISTS (SELECT 1 FROM circle_post_reads r WHERE r.post_id=p.id AND r.user_id=?) "
          +"ON CONFLICT (post_id,user_id) DO NOTHING";
        var parameters=new java.util.ArrayList<Object>();parameters.add(userId);parameters.addAll(page);parameters.add(userId);
        jdbc.update(statement,parameters.toArray());
      }
      return;
    }
    jdbc.batchUpdate(sql,postIds,100,(statement,id)->{statement.setLong(1,id);statement.setLong(2,userId);});
  }
}
