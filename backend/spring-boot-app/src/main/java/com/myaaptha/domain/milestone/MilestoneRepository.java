package com.myaaptha.domain.milestone;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.myaaptha.domain.milestone.model.MilestoneEntity;

@Repository
public interface MilestoneRepository extends JpaRepository<MilestoneEntity, Long> {
	List<MilestoneEntity> findByProjectId(Long projectId);
}
