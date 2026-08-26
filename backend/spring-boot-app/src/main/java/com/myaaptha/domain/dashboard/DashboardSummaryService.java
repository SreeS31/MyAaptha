package com.myaaptha.domain.dashboard;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;

import javax.sql.DataSource;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;

@Service
public class DashboardSummaryService {
  private final JdbcTemplate jdbcTemplate;

  public DashboardSummaryService(DataSource dataSource) {
    this.jdbcTemplate = new JdbcTemplate(dataSource);
  }

  public DashboardSummaryDto getSummary() {
    return jdbcTemplate.queryForObject(
        "SELECT user_count, person_count, circle_count, relationship_count, permission_count FROM dashboard_summary",
        new RowMapper<DashboardSummaryDto>() {
          @Override
          public DashboardSummaryDto mapRow(ResultSet rs, int rowNum) throws SQLException {
            DashboardSummaryDto dto = new DashboardSummaryDto();
            dto.setUserCount(rs.getLong("user_count"));
            dto.setPersonCount(rs.getLong("person_count"));
            dto.setCircleCount(rs.getLong("circle_count"));
            dto.setRelationshipCount(rs.getLong("relationship_count"));
            dto.setPermissionCount(rs.getLong("permission_count"));
            return dto;
          }
        });
  }
}
