package com.myaaptha.domain.ai;

import java.util.List;
import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiActionEventRepository extends JpaRepository<AiActionEventEntity, Long> {
  List<AiActionEventEntity> findTop50ByUserIdAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
      Long userId, Instant cutoff);
  void deleteByUserId(Long userId);
  void deleteByUserIdAndCreatedAtBefore(Long userId, Instant cutoff);
}
