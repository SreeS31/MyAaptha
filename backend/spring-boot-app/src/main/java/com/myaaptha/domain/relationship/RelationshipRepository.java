package com.myaaptha.domain.relationship;

import com.myaaptha.domain.relationship.model.RelationshipEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface RelationshipRepository extends JpaRepository<RelationshipEntity, Long> {
  List<RelationshipEntity> findByOwnerUserId(Long ownerUserId);
  List<RelationshipEntity> findByRelatedUserId(Long relatedUserId);
  Optional<RelationshipEntity> findByOwnerUserIdAndRelatedUserId(Long ownerUserId, Long relatedUserId);
  List<RelationshipEntity> findByOwnerUserIdIsNull();
}
