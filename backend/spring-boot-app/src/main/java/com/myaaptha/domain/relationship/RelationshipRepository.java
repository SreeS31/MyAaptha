package com.myaaptha.domain.relationship;

import com.myaaptha.domain.relationship.model.RelationshipEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface RelationshipRepository extends JpaRepository<RelationshipEntity, Long> {
  List<RelationshipEntity> findByOwnerUserId(Long ownerUserId);
  List<RelationshipEntity> findByOwnerUserIdInAndRelatedUserIdIn(java.util.Collection<Long> owners, java.util.Collection<Long> people);
  List<RelationshipEntity> findByOwnerUserId(Long ownerUserId,org.springframework.data.domain.Pageable page);
  List<RelationshipEntity> findByOwnerUserIdAndRelatedUserIdIn(Long ownerUserId,java.util.Collection<Long> ids);
  @org.springframework.data.jpa.repository.Query("select r from RelationshipEntity r where upper(r.visibilityScope)='PUBLIC' and ((r.ownerUserId in :known and r.relatedUserId in :targets) or (r.ownerUserId in :targets and r.relatedUserId in :known)) order by r.id")
  List<RelationshipEntity> publicConnections(@org.springframework.data.repository.query.Param("known") java.util.Collection<Long> known,
      @org.springframework.data.repository.query.Param("targets") java.util.Collection<Long> targets,org.springframework.data.domain.Pageable page);
  List<RelationshipEntity> findByRelatedUserId(Long relatedUserId);
  Optional<RelationshipEntity> findByOwnerUserIdAndRelatedUserId(Long ownerUserId, Long relatedUserId);
  List<RelationshipEntity> findByOwnerUserIdIsNull();
}
