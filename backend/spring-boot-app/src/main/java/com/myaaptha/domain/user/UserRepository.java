package com.myaaptha.domain.user;

import java.util.Optional;
import java.util.List;

import com.myaaptha.domain.user.model.UserEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

@Repository
public interface UserRepository extends JpaRepository<UserEntity, Long> {
  @Query("""
      select u from UserEntity u left join AppSettingsEntity s on s.userId=u.id
      left join UserProfileEntity p on p.userId=u.id
      where u.id<>:viewer and u.accountStatus in ('ACTIVE','MANAGED')
      and (s.discoverable=true or exists (select r.id from RelationshipEntity r where r.ownerUserId=:viewer and r.relatedUserId=u.id))
      and (lower(coalesce(u.firstName,'')) like :pattern escape '!' or lower(coalesce(u.surname,'')) like :pattern escape '!'
        or lower(concat(concat(coalesce(u.firstName,''),' '),coalesce(u.surname,''))) like :pattern escape '!'
        or lower(u.username) like :pattern escape '!' or lower(coalesce(u.location,'')) like :pattern escape '!'
        or (s.shareInterests=true and (lower(coalesce(p.hobbies,'')) like :pattern escape '!' or lower(coalesce(p.employer,'')) like :pattern escape '!')))
      order by u.firstName,u.surname,u.id
      """)
  List<UserEntity> discoverPeople(@Param("viewer") Long viewer,@Param("pattern") String pattern,org.springframework.data.domain.Pageable page);
	Optional<UserEntity> findByEmail(String email);

	Optional<UserEntity> findByUsername(String username);

	Optional<UserEntity> findByUsernameIgnoreCase(String username);

	boolean existsByEmail(String email);

	boolean existsByUsername(String username);

	Optional<UserEntity> findByPhoneNumber(String phoneNumber);

	boolean existsByPhoneNumber(String phoneNumber);

	@Query("""
		select u from UserEntity u where u.id <> :currentUserId and u.accountStatus in ('ACTIVE', 'MANAGED') and (
		  lower(coalesce(u.firstName, '')) like lower(concat('%', :query, '%')) or
		  lower(coalesce(u.surname, '')) like lower(concat('%', :query, '%')) or
		  lower(coalesce(u.location, '')) like lower(concat('%', :query, '%')) or
		  u.phoneNumber like concat('%', :query, '%'))
		order by u.firstName, u.surname, u.username
		""")
	List<UserEntity> searchPeople(@Param("currentUserId") Long currentUserId, @Param("query") String query,org.springframework.data.domain.Pageable pageable);
}
