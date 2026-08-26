package com.myaaptha.domain.project;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.myaaptha.domain.project.dto.CreateProjectRequest;
import com.myaaptha.domain.project.dto.ProjectDto;
import com.myaaptha.domain.project.model.ProjectEntity;

@Service
public class ProjectService {
  private final ProjectRepository projectRepository;

  public ProjectService(ProjectRepository projectRepository) {
    this.projectRepository = projectRepository;
  }

  public List<ProjectDto> listProjects() {
    return projectRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public ProjectDto createProject(CreateProjectRequest request) {
    ProjectEntity entity = new ProjectEntity();
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    entity.setStatus(request.getStatus());
    return toDto(projectRepository.save(entity));
  }

  public ProjectDto updateProject(Long id, CreateProjectRequest request) {
    ProjectEntity entity = projectRepository.findById(id)
      .orElseThrow(() -> new IllegalArgumentException("Project not found"));
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    entity.setStatus(request.getStatus());
    return toDto(projectRepository.save(entity));
  }

  private ProjectDto toDto(ProjectEntity entity) {
    ProjectDto dto = new ProjectDto();
    dto.setId(entity.getId());
    dto.setName(entity.getName());
    dto.setDescription(entity.getDescription());
    dto.setStatus(entity.getStatus());
    return dto;
  }
}
