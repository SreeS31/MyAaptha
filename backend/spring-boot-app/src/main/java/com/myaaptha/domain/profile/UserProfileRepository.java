package com.myaaptha.domain.profile;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
public interface UserProfileRepository extends JpaRepository<UserProfileEntity, Long> {}
