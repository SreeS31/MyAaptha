package com.myaaptha.domain.trust;
import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface EmergencyAccessRequestRepository extends JpaRepository<EmergencyAccessRequestEntity,Long>{
 List<EmergencyAccessRequestEntity> findByOwnerUserIdOrRequesterUserIdOrderByCreatedAtDesc(Long owner,Long requester);
 @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
 @org.springframework.data.jpa.repository.Query("select r from EmergencyAccessRequestEntity r where r.id=:id")
 Optional<EmergencyAccessRequestEntity> locked(@org.springframework.data.repository.query.Param("id") Long id);
 @org.springframework.data.jpa.repository.Query("select r from EmergencyAccessRequestEntity r where r.ownerUserId=:user or r.requesterUserId=:user or exists (select t.id from TrustedPersonEntity t where t.ownerUserId=r.ownerUserId and t.trustedUserId=:user and t.kind='STAR') order by r.createdAt desc")
 List<EmergencyAccessRequestEntity> visibleTo(@org.springframework.data.repository.query.Param("user") Long user);
}
