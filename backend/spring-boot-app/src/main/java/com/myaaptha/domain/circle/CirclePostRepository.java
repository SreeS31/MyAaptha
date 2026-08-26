package com.myaaptha.domain.circle;

import com.myaaptha.domain.circle.model.CirclePostEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CirclePostRepository extends JpaRepository<CirclePostEntity,Long> {
  List<CirclePostEntity> findByCircleIdOrderByCreatedAtAsc(Long circleId);
}
