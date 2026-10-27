package com.myaaptha.domain.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiActionApprovalRepository extends JpaRepository<AiActionApprovalEntity, UUID> {
  List<AiActionApprovalEntity> findTop100ByUserIdOrderByRequestedAtDesc(Long userId);
  Optional<AiActionApprovalEntity> findByIdAndUserId(UUID id, Long userId);
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select approval from AiActionApprovalEntity approval where approval.id = :id and approval.userId = :userId")
  Optional<AiActionApprovalEntity> lockByIdAndUserId(@Param("id") UUID id,
      @Param("userId") Long userId);
  Optional<AiActionApprovalEntity> findByUserIdAndPendingFingerprint(
      Long userId, String pendingFingerprint);
}
