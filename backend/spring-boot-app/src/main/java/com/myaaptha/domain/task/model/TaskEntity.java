package com.myaaptha.domain.task.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "tasks")
public class TaskEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String title;

  @Column(nullable = false)
  private String details;

  @Column(nullable = false)
  private String status;

  @Column
  private Long projectId;

  @Column
  private Long milestoneId;

  @Column
  private Long taskGroupId;

  public Long getId() {
    return id;
  }

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
