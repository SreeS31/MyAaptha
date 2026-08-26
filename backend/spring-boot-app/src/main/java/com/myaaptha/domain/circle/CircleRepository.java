package com.myaaptha.domain.circle;

import com.myaaptha.domain.circle.model.CircleEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

@Repository
public interface CircleRepository extends JpaRepository<CircleEntity, Long> {
  List<CircleEntity> findByOwnerUserId(Long ownerUserId);

  @Query(value = "SELECT DISTINCT c.* FROM circles c LEFT JOIN circle_members cm ON cm.circle_id = c.id "
      + "WHERE c.owner_user_id = :userId OR cm.user_id = :userId", nativeQuery = true)
  List<CircleEntity> findVisibleToUser(@Param("userId") Long userId);
}
