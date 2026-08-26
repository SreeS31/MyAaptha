package com.myaaptha.domain.dashboard;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardSummaryController {
  private final DashboardSummaryService dashboardSummaryService;

  public DashboardSummaryController(DashboardSummaryService dashboardSummaryService) {
    this.dashboardSummaryService = dashboardSummaryService;
  }

  @GetMapping("/summary")
  public ResponseEntity<DashboardSummaryDto> getSummary() {
    return ResponseEntity.ok(dashboardSummaryService.getSummary());
  }
}
