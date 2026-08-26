package com.myaaptha.domain.taskgroup;
import java.util.List;
import org.springframework.web.bind.annotation.*;
import com.myaaptha.domain.taskgroup.model.TaskGroupEntity;
@RestController @RequestMapping("/api/task-groups")
public class TaskGroupController {
  private final TaskGroupRepository repository;
  public TaskGroupController(TaskGroupRepository repository) { this.repository = repository; }
  @GetMapping public List<TaskGroupEntity> list() { return repository.findAll(); }
  @PostMapping public TaskGroupEntity create(@RequestBody TaskGroupEntity group) { return repository.save(group); }
}
