package com.myaaptha.domain.circle;
import com.myaaptha.domain.circle.model.CirclePostReactionEntity;import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface CirclePostReactionRepository extends JpaRepository<CirclePostReactionEntity,Long>{List<CirclePostReactionEntity> findByPostId(Long postId);Optional<CirclePostReactionEntity> findByPostIdAndUserId(Long postId,Long userId);}
