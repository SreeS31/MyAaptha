package com.myaaptha.domain.social;
import com.myaaptha.domain.message.DirectMessageService;
import com.myaaptha.domain.privacy.UserBlockRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/social/tools") @Transactional
public class SocialExtensionsController {
 public record Text(@Size(max=1000) String message){}
 public record Highlight(@Size(max=80) String name){}
 public record Collection(@NotBlank @Size(max=60) String name){}
 public record Reaction(String emoji){}
 public record Person(long id,String name){}
 public record Reactions(Map<String,Long> counts,String mine){}
 private final SocialService social;private final SocialStoryRepository stories;private final SocialSaveRepository saves;private final SocialPostRepository posts;private final JdbcTemplate db;private final RelationshipRepository relations;private final UserBlockRepository blocks;private final DirectMessageService direct;
 public SocialExtensionsController(SocialService social,SocialStoryRepository stories,SocialSaveRepository saves,SocialPostRepository posts,JdbcTemplate db,RelationshipRepository relations,UserBlockRepository blocks,DirectMessageService direct){this.social=social;this.stories=stories;this.saves=saves;this.posts=posts;this.db=db;this.relations=relations;this.blocks=blocks;this.direct=direct;}
 private long user(Principal p){return Long.parseLong(p.getName());}
 private ResponseStatusException error(HttpStatus status,String text){return new ResponseStatusException(status,text);}
 private Person person(java.sql.ResultSet rs,int n)throws java.sql.SQLException{String name=((Objects.requireNonNullElse(rs.getString("first_name"),"")+" "+Objects.requireNonNullElse(rs.getString("surname"),"")).trim());return new Person(rs.getLong("id"),name.isBlank()?rs.getString("username"):name);}
 @GetMapping("/close-friends") public List<Person> friends(Principal p){return db.query("SELECT u.id,u.first_name,u.surname,u.username FROM users u JOIN social_close_friends f ON f.member_user_id=u.id WHERE f.owner_user_id=? ORDER BY u.id",this::person,user(p));}
 @PostMapping("/close-friends/{member}") public void addFriend(Principal p,@PathVariable long member){long u=user(p);db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,u);if(u==member||blocks.blockedEitherWay(u,member)||relations.findByOwnerUserIdAndRelatedUserId(u,member).isEmpty()&&relations.findByOwnerUserIdAndRelatedUserId(member,u).isEmpty()||db.queryForObject("SELECT COUNT(*) FROM users WHERE id=? AND account_status='ACTIVE' AND identity_type<>'MANAGED'",Integer.class,member)!=1)throw error(HttpStatus.BAD_REQUEST,"Choose an active connected account");if(db.queryForObject("SELECT COUNT(*) FROM social_close_friends WHERE owner_user_id=? AND member_user_id=?",Integer.class,u,member)==0)db.update("INSERT INTO social_close_friends(owner_user_id,member_user_id) VALUES(?,?)",u,member);}
 @DeleteMapping("/close-friends/{member}") public void removeFriend(Principal p,@PathVariable long member){db.update("DELETE FROM social_close_friends WHERE owner_user_id=? AND member_user_id=?",user(p),member);}
 @GetMapping("/archive") public List<SocialDtos.Story> archive(Principal p){long u=user(p);return stories.findByAuthorUserIdOrderByCreatedAtDesc(u).stream().filter(s->s.getHighlightName()!=null||s.getArchiveUntil()!=null&&s.getArchiveUntil().isAfter(Instant.now())).map(s->social.storyDto(s,u)).toList();}
 @GetMapping("/highlights") public List<SocialDtos.Story> highlights(Principal p){long u=user(p);return stories.findTop100ByHighlightNameIsNotNullOrderByCreatedAtDesc().stream().filter(s->social.canViewStory(u,s)).map(s->social.storyDto(s,u)).toList();}
 @PostMapping("/stories/{storyId}/highlight") public SocialDtos.Story highlight(Principal p,@PathVariable long storyId,@Valid @RequestBody Highlight request){long u=user(p);var story=social.accessibleStory(u,storyId,true);if(!story.getAuthorUserId().equals(u))throw error(HttpStatus.FORBIDDEN,"Only the author can manage a highlight");String name=request.name()==null?"":request.name().trim();story.setHighlightName(name.isEmpty()?null:name);stories.save(story);return social.storyDto(story,u);}
 @GetMapping("/stories/{storyId}/viewers") public List<Person> viewers(Principal p,@PathVariable long storyId){long u=user(p);var story=social.accessibleStory(u,storyId,true);if(!story.getAuthorUserId().equals(u))throw error(HttpStatus.FORBIDDEN,"Only the author can see viewers");return db.query("SELECT u.id,u.first_name,u.surname,u.username FROM users u JOIN social_story_views v ON v.user_id=u.id WHERE v.story_id=? ORDER BY v.viewed_at DESC",this::person,storyId);}
 @GetMapping("/stories/{storyId}/reactions") public Reactions reactions(Principal p,@PathVariable long storyId){long u=user(p);var story=social.accessibleStory(u,storyId,true);var counts=new LinkedHashMap<String,Long>();db.query("SELECT emoji,COUNT(*) FROM social_story_reactions WHERE story_id=? AND (user_id=? OR ?=TRUE) GROUP BY emoji",rs->{counts.put(rs.getString(1),rs.getLong(2));},storyId,u,story.getAuthorUserId().equals(u));var mine=db.queryForList("SELECT emoji FROM social_story_reactions WHERE story_id=? AND user_id=?",String.class,storyId,u);return new Reactions(counts,mine.isEmpty()?null:mine.getFirst());}
 @PostMapping("/stories/{storyId}/reaction") public Reactions react(Principal p,@PathVariable long storyId,@RequestBody Reaction request){long u=user(p);social.accessibleStory(u,storyId,false);db.queryForObject("SELECT id FROM social_stories WHERE id=? FOR UPDATE",Long.class,storyId);String emoji=request.emoji();if(emoji!=null&&!Set.of("\uD83D\uDC4D","\u2764\uFE0F","\uD83D\uDE02","\uD83D\uDE2E","\uD83D\uDE22","\uD83D\uDE4F").contains(emoji))throw error(HttpStatus.BAD_REQUEST,"Choose a supported reaction");db.update("DELETE FROM social_story_reactions WHERE story_id=? AND user_id=?",storyId,u);if(emoji!=null)db.update("INSERT INTO social_story_reactions(story_id,user_id,emoji) VALUES(?,?,?)",storyId,u,emoji);return reactions(p,storyId);}
 @PostMapping("/stories/{storyId}/reply") public void reply(Principal p,@PathVariable long storyId,@Valid @RequestBody Text request){long u=user(p);var story=social.accessibleStory(u,storyId,false);if(story.getAuthorUserId().equals(u))throw error(HttpStatus.BAD_REQUEST,"Choose another person's story");if(request.message()==null||request.message().isBlank())throw error(HttpStatus.BAD_REQUEST,"Write a reply");direct.send(u,story.getAuthorUserId(),"Reply to your story: "+request.message().trim(),null);}
 public record CollectionInfo(String name,long count){}
 @GetMapping("/collections") public List<CollectionInfo> collections(Principal p){return db.query("SELECT name,COUNT(*) FROM social_saved_collections WHERE user_id=? GROUP BY name ORDER BY name",(rs,n)->new CollectionInfo(rs.getString(1),rs.getLong(2)),user(p));}
 @GetMapping("/collections/posts") public SocialService.PostPage collectionPosts(Principal p,@RequestParam String name,@RequestParam(defaultValue="9223372036854775807") long before){long u=user(p);var ids=db.queryForList("SELECT post_id FROM social_saved_collections WHERE user_id=? AND name=? AND post_id<? ORDER BY post_id DESC LIMIT 21",Long.class,u,name,before);var page=ids.stream().limit(20).toList();var items=new ArrayList<SocialDtos.Post>();for(long id:page){var post=posts.findById(id).orElse(null);if(post!=null&&social.canView(u,post))items.add(social.post(u,id));}return new SocialService.PostPage(items,ids.size()>20,page.isEmpty()?null:page.getLast());}
 @PostMapping("/collections/{postId}") public void collect(Principal p,@PathVariable long postId,@Valid @RequestBody Collection request){long u=user(p);db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,u);social.post(u,postId);if(!saves.contains(postId,u))saves.add(postId,u);String name=request.name().trim();if(db.queryForObject("SELECT COUNT(*) FROM social_saved_collections WHERE user_id=? AND post_id=? AND name=?",Integer.class,u,postId,name)==0)db.update("INSERT INTO social_saved_collections(post_id,user_id,name) VALUES(?,?,?)",postId,u,name);}
 @DeleteMapping("/collections/{postId}") public void uncollect(Principal p,@PathVariable long postId,@RequestParam String name){db.update("DELETE FROM social_saved_collections WHERE post_id=? AND user_id=? AND name=?",postId,user(p),name);}
}
