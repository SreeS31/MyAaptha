package com.myaaptha.platform.media;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MediaAssetRepository extends JpaRepository<MediaAssetEntity,Long>{
  Optional<MediaAssetEntity> findByStorageKeyAndDeletedAtIsNull(String key);
  @Query("select coalesce(sum(a.sizeBytes),0) from MediaAssetEntity a where a.ownerUserId=:owner and a.deletedAt is null") long activeBytes(@Param("owner") Long owner);
  List<MediaAssetEntity> findTop100ByExpiresAtBeforeAndDeletedAtIsNullOrderByExpiresAt(Instant now);
}
