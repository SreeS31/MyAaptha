package com.myaaptha.domain.circle.model;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "circle_posts")
public class CirclePostEntity {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  @Column(name="circle_id",nullable=false) private Long circleId;
  @Column(name="author_user_id",nullable=false) private Long authorUserId;
  @Column(name="parent_post_id") private Long parentPostId;
  @Column(length=4000,nullable=false) private String message = "";
  @Column(name="attachment_key") private String attachmentKey;
  @Column(name="attachment_name") private String attachmentName;
  @Column(name="attachment_type") private String attachmentType;
  @Column(name="attachment_size") private Long attachmentSize;
  @Column(name="created_at",nullable=false) private Instant createdAt = Instant.now();
  @Column(name="edited_at") private Instant editedAt;
  @Column(name="deleted_at") private Instant deletedAt;
  public Long getId(){return id;} public Long getCircleId(){return circleId;} public void setCircleId(Long v){circleId=v;}
  public Long getAuthorUserId(){return authorUserId;} public void setAuthorUserId(Long v){authorUserId=v;}
  public Long getParentPostId(){return parentPostId;} public void setParentPostId(Long v){parentPostId=v;}
  public String getMessage(){return message;} public void setMessage(String v){message=v;}
  public String getAttachmentKey(){return attachmentKey;} public void setAttachmentKey(String v){attachmentKey=v;}
  public String getAttachmentName(){return attachmentName;} public void setAttachmentName(String v){attachmentName=v;}
  public String getAttachmentType(){return attachmentType;} public void setAttachmentType(String v){attachmentType=v;}
  public Long getAttachmentSize(){return attachmentSize;} public void setAttachmentSize(Long v){attachmentSize=v;}
  public Instant getCreatedAt(){return createdAt;} public void setCreatedAt(Instant v){createdAt=v;}
  public Instant getEditedAt(){return editedAt;} public void setEditedAt(Instant v){editedAt=v;}
  public Instant getDeletedAt(){return deletedAt;} public void setDeletedAt(Instant v){deletedAt=v;}
}
