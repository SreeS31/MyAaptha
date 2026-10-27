package com.myaaptha.repository;

import com.myaaptha.domain.circle.Circle;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface CircleRepository extends JpaRepository<Circle, UUID> {
    Page<Circle> findByOwnerIdAndArchivedFalse(UUID ownerId, Pageable pageable);
    Page<Circle> findByOwnerId(UUID ownerId, Pageable pageable);
    long countByOwnerId(UUID ownerId);
}
