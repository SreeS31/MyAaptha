package com.myaaptha.domain.auth;

import java.util.Optional;

import com.myaaptha.domain.auth.model.AuthTokenEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AuthTokenRepository extends JpaRepository<AuthTokenEntity, Long> {
	@org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
	Optional<AuthTokenEntity> findByToken(String token);

  @org.springframework.data.jpa.repository.Query("select count(t)>0 from AuthTokenEntity t, UserEntity u where t.sessionId=:sid and t.userId=:userId and u.id=t.userId and u.accountStatus='ACTIVE' and u.role=:role and t.expiresAt>:now")
  boolean activeSession(@org.springframework.data.repository.query.Param("sid") String sid,@org.springframework.data.repository.query.Param("userId") Long userId,@org.springframework.data.repository.query.Param("role") String role,@org.springframework.data.repository.query.Param("now") java.time.Instant now);
	void deleteByToken(String token);
  @org.springframework.data.jpa.repository.Modifying(flushAutomatically=true)
  @org.springframework.data.jpa.repository.Query("delete from AuthTokenEntity t where t.token=:token and t.tokenType='refresh'")
  int consumeRefreshToken(@org.springframework.data.repository.query.Param("token") String token);

	void deleteByUserIdAndTokenType(Long userId, String tokenType);
  void deleteByUserIdAndExpiresAtBefore(Long userId, java.time.Instant expiry);
}
