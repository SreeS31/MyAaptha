package com.myaaptha.domain.project;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.myaaptha.domain.project.dto.CreateProjectRequest;
import com.myaaptha.domain.project.dto.ProjectDto;

@RestController
@RequestMapping("/api/projects")
public class ProjectController {
  private final ProjectService projectService;

  public ProjectController(ProjectService projectService) {
    this.projectService = projectService;
  }

  @GetMapping
  public List<ProjectDto> listProjects() {
    return projectService.listProjects();
  }

  @PostMapping
  public ProjectDto createProject(@RequestBody CreateProjectRequest request) {
    return projectService.createProject(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<ProjectDto> updateProject(@PathVariable Long id, @RequestBody CreateProjectRequest request) {
    try {
      return ResponseEntity.ok(projectService.updateProject(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}
