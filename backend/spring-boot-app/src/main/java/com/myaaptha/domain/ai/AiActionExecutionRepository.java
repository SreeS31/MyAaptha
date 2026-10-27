package com.myaaptha.domain.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiActionExecutionRepository extends JpaRepository<AiActionExecutionEntity, UUID> {
  Optional<AiActionExecutionEntity> findByApprovalId(UUID approvalId);
  Optional<AiActionExecutionEntity> findByIdAndUserId(UUID id, Long userId);
  List<AiActionExecutionEntity> findTop100ByUserIdOrderByStartedAtDesc(Long userId);
}
