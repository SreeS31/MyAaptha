package com.myaaptha.domain.social;
import com.myaaptha.domain.social.model.SocialPostEntity; import java.util.List; import org.springframework.data.jpa.repository.JpaRepository;
public interface SocialPostRepository extends JpaRepository<SocialPostEntity,Long>{List<SocialPostEntity> findTop100ByOrderByCreatedAtDesc();}
