package com.myaaptha.domain.ai;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiActionEventRepository extends JpaRepository<AiActionEventEntity, Long> {
  List<AiActionEventEntity> findTop50ByUserIdOrderByCreatedAtDesc(Long userId);
}
