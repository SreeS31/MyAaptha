package com.myaaptha.domain.circle;
import com.myaaptha.domain.circle.model.CirclePostReadEntity;import org.springframework.data.jpa.repository.JpaRepository;
public interface CirclePostReadRepository extends JpaRepository<CirclePostReadEntity,Long>{
  @org.springframework.data.jpa.repository.Query(value="SELECT COUNT(*) FROM circle_members m WHERE m.circle_id=:circle AND m.user_id<>:author AND NOT EXISTS (SELECT 1 FROM circle_post_reads r WHERE r.post_id=:post AND r.user_id=m.user_id)",nativeQuery=true)
  long unreadMembers(@org.springframework.data.repository.query.Param("circle") Long circle,@org.springframework.data.repository.query.Param("post") Long post,@org.springframework.data.repository.query.Param("author") Long author);
  boolean existsByPostIdAndUserId(Long postId,Long userId);
  long countByPostId(Long postId);
  interface ReadCount { Long getPostId(); long getReadCount(); }
  @org.springframework.data.jpa.repository.Query("select r.postId as postId, count(r) as readCount from CirclePostReadEntity r where r.postId in :ids group by r.postId")
  java.util.List<ReadCount> countsForPosts(@org.springframework.data.repository.query.Param("ids") java.util.List<Long> ids);
}
