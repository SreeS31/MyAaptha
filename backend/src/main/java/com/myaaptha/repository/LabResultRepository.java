package com.myaaptha.repository;

import com.myaaptha.domain.health.LabResult;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface LabResultRepository extends JpaRepository<LabResult, Long> {
    @Query("select r from LabResult r join fetch r.report p where p.userId = :userId order by p.reportDate, r.testName")
    List<LabResult> findHistory(@Param("userId") UUID userId);
}
