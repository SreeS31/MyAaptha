package com.circlenet.domain.trust;
import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface EmergencyAccessRequestRepository extends JpaRepository<EmergencyAccessRequestEntity,Long>{List<EmergencyAccessRequestEntity> findByOwnerUserIdOrRequesterUserIdOrderByCreatedAtDesc(Long owner,Long requester);}
