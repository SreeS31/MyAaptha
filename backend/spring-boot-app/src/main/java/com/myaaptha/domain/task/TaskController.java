package com.myaaptha.domain.task;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;

import com.myaaptha.domain.task.dto.CreateTaskRequest;
import com.myaaptha.domain.task.dto.TaskDto;

@RestController
@RequestMapping("/api/tasks")
public class TaskController {
  private final TaskService taskService;

  public TaskController(TaskService taskService) {
    this.taskService = taskService;
  }

  @GetMapping
  public List<TaskDto> listTasks(@RequestParam(required = false) Long projectId, @RequestParam(required = false) Long milestoneId) {
    return taskService.listTasks(projectId, milestoneId);
  }

  @PostMapping
  public TaskDto createTask(@RequestBody CreateTaskRequest request) {
    return taskService.createTask(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<TaskDto> updateTask(@PathVariable Long id, @RequestBody CreateTaskRequest request) {
    try {
      return ResponseEntity.ok(taskService.updateTask(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}
