package com.myaaptha.domain.dashboard;

public class DashboardSummaryDto {
  private Long userCount;
  private Long personCount;
  private Long circleCount;
  private Long relationshipCount;
  private Long permissionCount;

  public Long getUserCount() {
    return userCount;
  }

  public void setUserCount(Long userCount) {
    this.userCount = userCount;
  }

  public Long getPersonCount() {
    return personCount;
  }

  public void setPersonCount(Long personCount) {
    this.personCount = personCount;
  }

  public Long getCircleCount() {
    return circleCount;
  }

  public void setCircleCount(Long circleCount) {
    this.circleCount = circleCount;
  }

  public Long getRelationshipCount() {
    return relationshipCount;
  }

  public void setRelationshipCount(Long relationshipCount) {
    this.relationshipCount = relationshipCount;
  }

  public Long getPermissionCount() {
    return permissionCount;
  }

  public void setPermissionCount(Long permissionCount) {
    this.permissionCount = permissionCount;
  }
}
