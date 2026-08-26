package com.myaaptha.domain.task.dto;

public class CreateTaskRequest {
  private String title;
  private String details;
  private String status;
  private Long projectId;
  private Long milestoneId;
  private Long taskGroupId;

  public String getTitle() {
    return title;
  }

  public void setTitle(String title) {
    this.title = title;
  }

  public String getDetails() {
    return details;
  }

  public void setDetails(String details) {
    this.details = details;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String status) {
    this.status = status;
  }

  public Long getProjectId() {
    return projectId;
  }

  public void setProjectId(Long projectId) {
    this.projectId = projectId;
  }

  public Long getMilestoneId() {
    return milestoneId;
  }

  public void setMilestoneId(Long milestoneId) {
    this.milestoneId = milestoneId;
  }
  public Long getTaskGroupId() { return taskGroupId; }
  public void setTaskGroupId(Long taskGroupId) { this.taskGroupId = taskGroupId; }
}
