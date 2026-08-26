package com.myaaptha.domain.social;
import org.springframework.data.jpa.repository.*;import org.springframework.data.repository.Repository;import org.springframework.data.repository.query.Param;import org.springframework.transaction.annotation.Transactional;
public interface SocialStoryViewRepository extends Repository<com.myaaptha.domain.social.model.SocialStoryEntity,Long>{
 @Query(value="select count(*) from social_story_views where story_id=:storyId",nativeQuery=true) long countFor(@Param("storyId") Long storyId);
 @Query(value="select count(*) > 0 from social_story_views where story_id=:storyId and user_id=:userId",nativeQuery=true) boolean contains(@Param("storyId") Long storyId,@Param("userId") Long userId);
 @Modifying @Transactional @Query(value="insert into social_story_views(story_id,user_id) values(:storyId,:userId)",nativeQuery=true) void add(@Param("storyId") Long storyId,@Param("userId") Long userId);
}
