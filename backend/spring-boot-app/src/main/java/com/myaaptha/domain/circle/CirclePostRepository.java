package com.myaaptha.domain.circle;

import com.myaaptha.domain.circle.model.CirclePostEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CirclePostRepository extends JpaRepository<CirclePostEntity,Long> {
  @org.springframework.data.jpa.repository.Query(value="""
    SELECT p.* FROM circle_posts p JOIN
      (SELECT MAX(p2.id) AS id FROM circle_posts p2 JOIN circle_members cm ON cm.circle_id=p2.circle_id
       WHERE cm.user_id=:userId AND NOT EXISTS
         (SELECT 1 FROM circle_post_hidden h WHERE h.post_id=p2.id AND h.user_id=:userId)
       GROUP BY p2.circle_id) latest ON latest.id=p.id ORDER BY p.id DESC
    """,nativeQuery=true)
  List<CirclePostEntity> latestConversations(@org.springframework.data.repository.query.Param("userId") Long userId);
  interface UnreadCount { Long getCircleId(); Long getUnreadCount(); }
  @org.springframework.data.jpa.repository.Query(value="""
      SELECT c.id AS circleId, COUNT(p.id) AS unreadCount
      FROM circle_members cm JOIN circles c ON c.id=cm.circle_id
      LEFT JOIN circle_posts p ON p.circle_id=c.id AND p.author_user_id<>:userId AND p.deleted_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM circle_post_hidden h WHERE h.post_id=p.id AND h.user_id=:userId)
        AND NOT EXISTS (SELECT 1 FROM circle_post_reads r WHERE r.post_id=p.id AND r.user_id=:userId)
      WHERE cm.user_id=:userId GROUP BY c.id
      """, nativeQuery=true)
  List<UnreadCount> unreadCounts(@org.springframework.data.repository.query.Param("userId") Long userId);
  List<CirclePostEntity> findByCircleIdOrderByCreatedAtAsc(Long circleId);

  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query("select p from CirclePostEntity p where p.circleId=:circleId and p.id<:before order by p.id desc")
  List<CirclePostEntity> visiblePage(@org.springframework.data.repository.query.Param("circleId") Long circleId,@org.springframework.data.repository.query.Param("before") Long before,org.springframework.data.domain.Pageable pageable);
  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query("select p from CirclePostEntity p where p.id=:id")
  java.util.Optional<CirclePostEntity> locked(@org.springframework.data.repository.query.Param("id") Long id);
  List<CirclePostEntity> findByCircleIdAndIdLessThanOrderByIdDesc(Long circleId,Long before,org.springframework.data.domain.Pageable pageable);
  @org.springframework.data.jpa.repository.Query("select p from CirclePostEntity p where p.circleId=:circleId and :userId not member of p.hiddenForUsers and p.deletedAt is null and (locate(:q,lower(p.message))>0 or locate(:q,lower(p.attachmentName))>0) order by p.id desc")
  List<CirclePostEntity> search(@org.springframework.data.repository.query.Param("userId") Long userId,@org.springframework.data.repository.query.Param("circleId") Long circleId,@org.springframework.data.repository.query.Param("q") String q,org.springframework.data.domain.Pageable pageable);
}
