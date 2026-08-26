package com.myaaptha.domain.trust;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface TrustedPersonRepository extends JpaRepository<TrustedPersonEntity,Long>{List<TrustedPersonEntity> findByOwnerUserIdAndKindOrderByCreatedAtDesc(Long owner,String kind);List<TrustedPersonEntity> findByTrustedUserIdAndKindOrderByCreatedAtDesc(Long user,String kind);Optional<TrustedPersonEntity> findByOwnerUserIdAndTrustedUserIdAndKind(Long owner,Long trusted,String kind);long countByOwnerUserIdAndKind(Long owner,String kind);}
