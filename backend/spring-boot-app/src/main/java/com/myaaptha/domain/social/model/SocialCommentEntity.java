package com.myaaptha.domain.social.model;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="social_comments") public class SocialCommentEntity {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(name="post_id",nullable=false) private Long postId; @Column(name="author_user_id",nullable=false) private Long authorUserId; @Column(length=1000,nullable=false) private String message; @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
 public Long getId(){return id;} public Long getPostId(){return postId;} public void setPostId(Long v){postId=v;} public Long getAuthorUserId(){return authorUserId;} public void setAuthorUserId(Long v){authorUserId=v;} public String getMessage(){return message;} public void setMessage(String v){message=v;} public Instant getCreatedAt(){return createdAt;}
}
