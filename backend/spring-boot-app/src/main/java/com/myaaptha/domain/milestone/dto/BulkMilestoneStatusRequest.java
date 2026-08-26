package com.myaaptha.domain.milestone.dto;

import java.util.List;

public class BulkMilestoneStatusRequest {
  private List<Long> milestoneIds;
  private String status;
  private String blockedReason;

  public List<Long> getMilestoneIds() {
    return milestoneIds;
  }

  public void setMilestoneIds(List<Long> milestoneIds) {
    this.milestoneIds = milestoneIds;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String status) {
    this.status = status;
  }

  public String getBlockedReason() {
    return blockedReason;
  }

  public void setBlockedReason(String blockedReason) {
    this.blockedReason = blockedReason;
  }
}
