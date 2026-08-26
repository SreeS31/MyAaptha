package com.myaaptha.domain.task;

import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import com.myaaptha.domain.task.dto.CreateTaskRequest;
import com.myaaptha.domain.task.dto.TaskDto;
import com.myaaptha.domain.task.model.TaskEntity;

@Service
public class TaskService {
  private final TaskRepository taskRepository;
  public TaskService(TaskRepository taskRepository) { this.taskRepository = taskRepository; }
  public List<TaskDto> listTasks(Long projectId, Long milestoneId) {
    if (milestoneId != null) return taskRepository.findByMilestoneId(milestoneId).stream().map(this::toDto).collect(Collectors.toList());
    if (projectId != null) return taskRepository.findByProjectId(projectId).stream().map(this::toDto).collect(Collectors.toList());
    return listTasks();
  }
  public List<TaskDto> listTasks() { return taskRepository.findAll().stream().map(this::toDto).collect(Collectors.toList()); }
  public TaskDto createTask(CreateTaskRequest request) { TaskEntity entity = new TaskEntity(); apply(entity, request); return toDto(taskRepository.save(entity)); }
  public TaskDto updateTask(Long id, CreateTaskRequest request) { TaskEntity entity = taskRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Task not found")); apply(entity, request); return toDto(taskRepository.save(entity)); }
  private void apply(TaskEntity entity, CreateTaskRequest request) { entity.setTitle(request.getTitle()); entity.setDetails(request.getDetails()); entity.setStatus(request.getStatus()); entity.setProjectId(request.getProjectId()); entity.setMilestoneId(request.getMilestoneId()); entity.setTaskGroupId(request.getTaskGroupId()); }
  private TaskDto toDto(TaskEntity entity) { TaskDto dto = new TaskDto(); dto.setId(entity.getId()); dto.setTitle(entity.getTitle()); dto.setDetails(entity.getDetails()); dto.setStatus(entity.getStatus()); dto.setProjectId(entity.getProjectId()); dto.setMilestoneId(entity.getMilestoneId()); dto.setTaskGroupId(entity.getTaskGroupId()); return dto; }
}
