package com.myaaptha.domain.privacy;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface UserBlockRepository extends JpaRepository<UserBlockEntity,Long>{
  List<UserBlockEntity> findByBlockerUserIdOrBlockedUserId(Long blocker,Long blocked);
  List<UserBlockEntity> findByBlockerUserIdInAndBlockedUserIdIn(Collection<Long> blockers,Collection<Long> blocked);
  Optional<UserBlockEntity> findByBlockerUserIdAndBlockedUserId(Long blocker,Long blocked);List<UserBlockEntity> findByBlockerUserIdOrderByCreatedAtDesc(Long blocker);boolean existsByBlockerUserIdAndBlockedUserId(Long blocker,Long blocked);default boolean blockedEitherWay(Long first,Long second){return existsByBlockerUserIdAndBlockedUserId(first,second)||existsByBlockerUserIdAndBlockedUserId(second,first);}}
