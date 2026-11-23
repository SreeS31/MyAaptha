package com.myaaptha.domain.social;
import com.myaaptha.domain.social.model.SocialStoryEntity; import java.time.Instant; import java.util.List; import org.springframework.data.jpa.repository.JpaRepository;
public interface SocialStoryRepository extends JpaRepository<SocialStoryEntity,Long>{
 @org.springframework.data.jpa.repository.Query("select s from SocialStoryEntity s where s.highlightName is null and s.expiresAt<:now and (s.archiveUntil is null or s.archiveUntil<:now) order by s.expiresAt")
 List<SocialStoryEntity> cleanupCandidates(@org.springframework.data.repository.query.Param("now") Instant now,org.springframework.data.domain.Pageable page);
 List<SocialStoryEntity> findByAuthorUserIdOrderByCreatedAtDesc(Long author);
 List<SocialStoryEntity> findTop100ByHighlightNameIsNotNullOrderByCreatedAtDesc();
 List<SocialStoryEntity> findTop100ByHighlightNameIsNullAndExpiresAtBeforeOrderByExpiresAt(Instant now);
 List<SocialStoryEntity> findByExpiresAtAfterOrderByCreatedAtDesc(Instant now);
 List<SocialStoryEntity> findTop100ByExpiresAtBeforeOrderByExpiresAt(Instant now);
}
