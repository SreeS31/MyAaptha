package com.myaaptha.domain.taskgroup;
import org.springframework.data.jpa.repository.JpaRepository;
import com.myaaptha.domain.taskgroup.model.TaskGroupEntity;
public interface TaskGroupRepository extends JpaRepository<TaskGroupEntity, Long> { }
