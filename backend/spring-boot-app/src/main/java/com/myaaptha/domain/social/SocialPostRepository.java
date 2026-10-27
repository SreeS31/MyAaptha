package com.myaaptha.domain.social;
import com.myaaptha.domain.social.model.SocialPostEntity; import java.util.List; import org.springframework.data.jpa.repository.JpaRepository;
public interface SocialPostRepository extends JpaRepository<SocialPostEntity,Long>{List<SocialPostEntity> findTop100ByOrderByCreatedAtDesc();
 @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
 @org.springframework.data.jpa.repository.Query("select p from SocialPostEntity p where p.id=:id")
 java.util.Optional<SocialPostEntity> findForUpdate(@org.springframework.data.repository.query.Param("id") Long id);
 @org.springframework.data.jpa.repository.Query(value="select p.* from social_posts p join social_post_flags f on f.post_id=p.id where f.user_id=:viewer and f.pinned=true order by p.created_at desc",nativeQuery=true)
 List<SocialPostEntity> findPinned(@org.springframework.data.repository.query.Param("viewer") Long viewer);
 List<SocialPostEntity> findTop100ByAuthorUserIdAndAudienceAndMediaKeyIsNotNullOrderByCreatedAtDesc(Long author,String audience);
}
