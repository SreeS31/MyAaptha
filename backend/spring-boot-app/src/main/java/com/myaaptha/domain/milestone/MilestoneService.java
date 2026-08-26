package com.myaaptha.domain.milestone;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.myaaptha.domain.milestone.dto.BulkMilestoneStatusRequest;
import com.myaaptha.domain.milestone.dto.CreateMilestoneRequest;
import com.myaaptha.domain.milestone.dto.MilestoneDto;
import com.myaaptha.domain.milestone.model.MilestoneEntity;

@Service
public class MilestoneService {
  private final MilestoneRepository milestoneRepository;

  public MilestoneService(MilestoneRepository milestoneRepository) {
    this.milestoneRepository = milestoneRepository;
  }

  public List<MilestoneDto> listMilestones(Long projectId) {
    if (projectId != null) {
      return milestoneRepository.findByProjectId(projectId).stream().map(this::toDto).collect(Collectors.toList());
    }

    return listMilestones();
  }

  public List<MilestoneDto> listMilestones() {
    return milestoneRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public MilestoneDto getMilestone(Long id) {
    return milestoneRepository.findById(id).map(this::toDto).orElseThrow(() -> new IllegalArgumentException("Milestone not found"));
  }

  public MilestoneDto createMilestone(CreateMilestoneRequest request) {
    MilestoneEntity entity = new MilestoneEntity();
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    entity.setStatus(request.getStatus());
    entity.setProjectId(request.getProjectId());
    entity.setDueDate(request.getDueDate());
    entity.setBlockedReason(normalizeBlockedReason(request.getStatus(), request.getBlockedReason()));
    return toDto(milestoneRepository.save(entity));
  }

  public MilestoneDto updateMilestone(Long id, CreateMilestoneRequest request) {
    MilestoneEntity entity = milestoneRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Milestone not found"));
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    entity.setStatus(request.getStatus());
    entity.setProjectId(request.getProjectId());
    entity.setDueDate(request.getDueDate());
    entity.setBlockedReason(normalizeBlockedReason(request.getStatus(), request.getBlockedReason()));
    return toDto(milestoneRepository.save(entity));
  }

  public List<MilestoneDto> bulkUpdateStatus(BulkMilestoneStatusRequest request) {
    if (request.getMilestoneIds() == null || request.getMilestoneIds().isEmpty()) {
      throw new IllegalArgumentException("At least one milestone id is required");
    }

    if (request.getStatus() == null || request.getStatus().isBlank()) {
      throw new IllegalArgumentException("Status is required");
    }

    List<MilestoneEntity> milestones = milestoneRepository.findAllById(request.getMilestoneIds());
    if (milestones.size() != request.getMilestoneIds().size()) {
      throw new IllegalArgumentException("One or more milestones not found");
    }

    String normalizedBlockedReason = normalizeBlockedReason(request.getStatus(), request.getBlockedReason());
    milestones.forEach((milestone) -> {
      milestone.setStatus(request.getStatus());
      milestone.setBlockedReason(normalizedBlockedReason);
    });
    return milestoneRepository.saveAll(milestones).stream().map(this::toDto).collect(Collectors.toList());
  }

  public void deleteMilestone(Long id) {
    milestoneRepository.deleteById(id);
  }

  private MilestoneDto toDto(MilestoneEntity entity) {
    MilestoneDto dto = new MilestoneDto();
    dto.setId(entity.getId());
    dto.setName(entity.getName());
    dto.setDescription(entity.getDescription());
    dto.setStatus(entity.getStatus());
    dto.setProjectId(entity.getProjectId());
    dto.setDueDate(entity.getDueDate());
    dto.setBlockedReason(entity.getBlockedReason());
    return dto;
  }

  private String normalizeBlockedReason(String status, String blockedReason) {
    if ("Blocked".equals(status)) {
      if (blockedReason == null || blockedReason.isBlank()) {
        throw new IllegalArgumentException("Blocked reason is required when status is Blocked");
      }
      return blockedReason.trim();
    }

    return null;
  }
}
