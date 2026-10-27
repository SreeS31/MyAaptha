package com.myaaptha.repository;

import com.myaaptha.domain.node.PersonNode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface PersonNodeRepository extends JpaRepository<PersonNode, UUID> {
    Page<PersonNode> findByCircleId(UUID circleId, Pageable pageable);
    List<PersonNode> findByCircleIdAndParentIdIsNull(UUID circleId);
    List<PersonNode> findByCircleIdAndParentId(UUID circleId, UUID parentId);
    long countByCircleId(UUID circleId);

    @Query("SELECT n FROM PersonNode n WHERE n.circleId = :circleId AND " +
           "(LOWER(n.fullName) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(n.company) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           "LOWER(n.city) LIKE LOWER(CONCAT('%', :query, '%')))")
    Page<PersonNode> searchInCircle(@Param("circleId") UUID circleId,
                                    @Param("query") String query,
                                    Pageable pageable);
}
