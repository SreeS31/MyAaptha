package com.myaaptha.domain.auth;

import java.util.Optional;

import com.myaaptha.domain.auth.model.AuthTokenEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AuthTokenRepository extends JpaRepository<AuthTokenEntity, Long> {
	Optional<AuthTokenEntity> findByToken(String token);

	void deleteByToken(String token);

	void deleteByUserIdAndTokenType(Long userId, String tokenType);
}
