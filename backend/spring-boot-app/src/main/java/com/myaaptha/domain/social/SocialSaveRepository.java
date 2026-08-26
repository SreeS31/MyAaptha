package com.myaaptha.domain.social;

import java.util.Set;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface SocialSaveRepository extends Repository<com.myaaptha.domain.social.model.SocialPostEntity,Long> {
  @Query(value="select post_id from social_post_saves where user_id=:userId",nativeQuery=true) Set<Long> postsFor(@Param("userId") Long userId);
  @Query(value="select count(*) > 0 from social_post_saves where post_id=:postId and user_id=:userId",nativeQuery=true) boolean contains(@Param("postId") Long postId,@Param("userId") Long userId);
  @Modifying @Transactional @Query(value="insert into social_post_saves(post_id,user_id) values(:postId,:userId)",nativeQuery=true) void add(@Param("postId") Long postId,@Param("userId") Long userId);
  @Modifying @Transactional @Query(value="delete from social_post_saves where post_id=:postId and user_id=:userId",nativeQuery=true) void remove(@Param("postId") Long postId,@Param("userId") Long userId);
}
