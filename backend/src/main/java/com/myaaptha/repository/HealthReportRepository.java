package com.myaaptha.repository;

import com.myaaptha.domain.health.HealthReport;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface HealthReportRepository extends JpaRepository<HealthReport, UUID> {
    List<HealthReport> findByUserIdOrderByReportDateDescCreatedAtDesc(UUID userId);
}
