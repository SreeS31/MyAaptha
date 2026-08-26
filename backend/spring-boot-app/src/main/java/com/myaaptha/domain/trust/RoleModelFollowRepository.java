package com.myaaptha.domain.trust;
import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface RoleModelFollowRepository extends JpaRepository<RoleModelFollowEntity,Long>{Optional<RoleModelFollowEntity> findByFollowerUserIdAndRoleModelUserId(Long follower,Long roleModel);List<RoleModelFollowEntity> findByFollowerUserIdOrderByCreatedAtDesc(Long follower);long countByRoleModelUserId(Long roleModel);}
