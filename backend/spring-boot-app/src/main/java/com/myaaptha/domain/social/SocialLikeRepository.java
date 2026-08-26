package com.myaaptha.domain.social;
import java.util.Set; import org.springframework.data.jpa.repository.*; import org.springframework.data.repository.Repository; import org.springframework.data.repository.query.Param; import org.springframework.transaction.annotation.Transactional;
public interface SocialLikeRepository extends Repository<com.myaaptha.domain.social.model.SocialPostEntity,Long>{
 @Query(value="select count(*) from social_post_likes where post_id=:postId",nativeQuery=true) long countFor(@Param("postId") Long postId);
 @Query(value="select user_id from social_post_likes where post_id=:postId",nativeQuery=true) Set<Long> usersFor(@Param("postId") Long postId);
 @Modifying @Transactional @Query(value="insert into social_post_likes(post_id,user_id) values(:postId,:userId)",nativeQuery=true) void add(@Param("postId") Long postId,@Param("userId") Long userId);
 @Modifying @Transactional @Query(value="delete from social_post_likes where post_id=:postId and user_id=:userId",nativeQuery=true) void remove(@Param("postId") Long postId,@Param("userId") Long userId);
}
