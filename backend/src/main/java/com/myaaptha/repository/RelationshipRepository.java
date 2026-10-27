package com.myaaptha.repository;

import com.myaaptha.domain.relationship.Relationship;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface RelationshipRepository extends JpaRepository<Relationship, UUID> {
    List<Relationship> findByCircleId(UUID circleId);
    List<Relationship> findBySourceNodeIdOrTargetNodeId(UUID sourceNodeId, UUID targetNodeId);
    List<Relationship> findBySourceNodeId(UUID sourceNodeId);
    List<Relationship> findByTargetNodeId(UUID targetNodeId);
}
