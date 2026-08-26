package com.myaaptha.domain.task.dto;
public class TaskDto {
  private Long id; private String title; private String details; private String status; private Long projectId; private Long milestoneId; private Long taskGroupId;
  public Long getId(){return id;} public void setId(Long value){id=value;}
  public String getTitle(){return title;} public void setTitle(String value){title=value;}
  public String getDetails(){return details;} public void setDetails(String value){details=value;}
  public String getStatus(){return status;} public void setStatus(String value){status=value;}
  public Long getProjectId(){return projectId;} public void setProjectId(Long value){projectId=value;}
  public Long getMilestoneId(){return milestoneId;} public void setMilestoneId(Long value){milestoneId=value;}
  public Long getTaskGroupId(){return taskGroupId;} public void setTaskGroupId(Long value){taskGroupId=value;}
}
