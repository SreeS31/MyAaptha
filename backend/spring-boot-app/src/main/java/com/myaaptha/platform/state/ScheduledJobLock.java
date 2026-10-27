package com.myaaptha.platform.state;
import org.springframework.stereotype.Component;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.*;
@Component
public class ScheduledJobLock {
  private final JdbcTemplate jdbc;
  public ScheduledJobLock(JdbcTemplate jdbc){this.jdbc=jdbc;}
  /** The caller must hold its transaction for the entire bounded cleanup batch. */
  @Transactional(propagation=Propagation.MANDATORY)
  public boolean acquire(String name){return !jdbc.queryForList("SELECT name FROM scheduled_job_locks WHERE name=? FOR UPDATE SKIP LOCKED",String.class,name).isEmpty();}
}
