package com.myaaptha.domain.social;

import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest
@Transactional
class SocialPostOptionsTest {
 @Autowired SocialService service;@Autowired UserRepository users;@Autowired JdbcTemplate db;@Autowired SocialPostRepository posts;
 long member(){var u=new UserEntity();u.setUsername("post-options-"+UUID.randomUUID());u.setPasswordHash("synthetic");return users.saveAndFlush(u).getId();}
 SocialDtos.Post post(long owner,String audience){return service.createPost(owner,"Synthetic post",audience,null,null);}
 @Test void reactionReplacementIsIdempotentAndLegacyLikeStillWorks(){long u=member();long id=post(u,"PRIVATE").id();var first=service.react(u,id,"😂");assertThat(first.myReaction()).isEqualTo("😂");assertThat(first.reactions()).containsEntry("😂",1L);assertThat(service.react(u,id,"😂").likeCount()).isEqualTo(1);assertThat(service.react(u,id,"❤️").reactions()).containsOnlyKeys("❤️");assertThat(service.toggleLike(u,id).likeCount()).isZero();assertThat(service.toggleLike(u,id).myReaction()).isEqualTo("👍");assertThat(service.react(u,id,null).likeCount()).isZero();}
 @Test void customSingleEmojiSupportsModifiersAndRejectsArbitraryText(){long u=member(),id=post(u,"PRIVATE").id();assertThat(service.react(u,id,"👩🏽‍💻").myReaction()).isEqualTo("👩🏽‍💻");for(String bad:List.of("hello","👍😂","<script>","","ȧ"))assertThatThrownBy(()->service.react(u,id,bad)).isInstanceOf(ResponseStatusException.class);assertThat(service.react(u,id,"🇮🇳").myReaction()).isEqualTo("🇮🇳");}
 @Test void privateContentCannotBeReactedToOrPinnedByAnotherAccount(){long owner=member(),other=member(),id=post(owner,"PRIVATE").id();assertThatThrownBy(()->service.react(other,id,"👍")).isInstanceOf(ResponseStatusException.class);assertThatThrownBy(()->service.pin(other,id,true)).isInstanceOf(ResponseStatusException.class);assertThat(service.feed(owner).get(0).likeCount()).isZero();}
 @Test void pinsArePersonalIdempotentAndOrderedBeforeNewerPosts(){long owner=member(),other=member(),id=post(owner,"PUBLIC").id();post(owner,"PUBLIC");assertThat(service.pin(owner,id,true).pinned()).isTrue();service.pin(owner,id,true);assertThat(service.feed(owner).get(0).id()).isEqualTo(id);assertThat(service.feed(other).stream().filter(p->p.id().equals(id)).findFirst().orElseThrow().pinned()).isFalse();assertThat(service.pin(owner,id,false).pinned()).isFalse();}
 @Test void deletingPostRemovesReactionsPinsAndStars(){long u=member(),id=post(u,"PRIVATE").id();service.react(u,id,"🔥");service.pin(u,id,true);service.toggleSave(u,id);service.deletePost(u,id);posts.flush();assertThat(db.queryForObject("select count(*) from social_post_flags where post_id=?",Long.class,id)).isZero();assertThat(db.queryForObject("select count(*) from social_post_likes where post_id=?",Long.class,id)).isZero();assertThat(service.saved(u)).isEmpty();}
}
