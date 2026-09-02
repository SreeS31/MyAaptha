package com.myaaptha.domain.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiActionApprovalRepository extends JpaRepository<AiActionApprovalEntity, UUID> {
  List<AiActionApprovalEntity> findTop100ByUserIdOrderByRequestedAtDesc(Long userId);
  Optional<AiActionApprovalEntity> findByIdAndUserId(UUID id, Long userId);
  Optional<AiActionApprovalEntity> findByUserIdAndPendingFingerprint(
      Long userId, String pendingFingerprint);
}
