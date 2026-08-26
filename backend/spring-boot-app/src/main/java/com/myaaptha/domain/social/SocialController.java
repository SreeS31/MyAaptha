package com.myaaptha.domain.social;
import java.security.Principal; import java.util.List; import org.springframework.core.io.Resource; import org.springframework.http.*; import org.springframework.web.bind.annotation.*; import org.springframework.web.multipart.MultipartFile;
@RestController @RequestMapping("/api/social") public class SocialController { private final SocialService service; public SocialController(SocialService s){service=s;}
 @GetMapping("/feed") public List<SocialDtos.Post> feed(Principal p){return service.feed(id(p));}
 @GetMapping("/saved") public List<SocialDtos.Post> saved(Principal p){return service.saved(id(p));}
 @PostMapping(value="/posts",consumes=MediaType.MULTIPART_FORM_DATA_VALUE) public SocialDtos.Post create(Principal p,@RequestParam(required=false) String caption,@RequestParam(required=false) String audience,@RequestParam(required=false) Long circleId,@RequestPart(required=false) MultipartFile file){return service.createPost(id(p),caption,audience,circleId,file);}
 @PutMapping("/posts/{postId}") public SocialDtos.Post update(Principal p,@PathVariable Long postId,@RequestBody SocialDtos.CaptionRequest r){return service.updatePost(id(p),postId,r.caption());}
 @DeleteMapping("/posts/{postId}") public ResponseEntity<Void> delete(Principal p,@PathVariable Long postId){service.deletePost(id(p),postId);return ResponseEntity.noContent().build();}
 @PostMapping("/posts/{postId}/like") public SocialDtos.Post like(Principal p,@PathVariable Long postId){return service.toggleLike(id(p),postId);}
 @PostMapping("/posts/{postId}/save") public SocialDtos.Post save(Principal p,@PathVariable Long postId){return service.toggleSave(id(p),postId);}
 @PostMapping("/posts/{postId}/share") public SocialDtos.ShareResult share(Principal p,@PathVariable Long postId,@RequestBody SocialDtos.ShareRequest r){return service.share(id(p),postId,r);}
 @PostMapping("/posts/{postId}/comments") public SocialDtos.Comment comment(Principal p,@PathVariable Long postId,@RequestBody SocialDtos.CommentRequest r){return service.comment(id(p),postId,r.message());}
 @DeleteMapping("/posts/{postId}/comments/{commentId}") public ResponseEntity<Void> deleteComment(Principal p,@PathVariable Long postId,@PathVariable Long commentId){service.deleteComment(id(p),postId,commentId);return ResponseEntity.noContent().build();}
 @GetMapping("/posts/{postId}/media") public ResponseEntity<Resource> postMedia(Principal p,@PathVariable Long postId){return resource(service.postMedia(id(p),postId));}
 @GetMapping("/stories") public List<SocialDtos.Story> stories(Principal p){return service.activeStories(id(p));}
 @PostMapping(value="/stories",consumes=MediaType.MULTIPART_FORM_DATA_VALUE) public SocialDtos.Story story(Principal p,@RequestParam(required=false) String caption,@RequestParam(required=false) String audience,@RequestPart MultipartFile file){return service.createStory(id(p),caption,audience,file);}
 @PostMapping("/stories/{storyId}/view") public SocialDtos.Story viewStory(Principal p,@PathVariable Long storyId){return service.viewStory(id(p),storyId);}
 @DeleteMapping("/stories/{storyId}") public ResponseEntity<Void> deleteStory(Principal p,@PathVariable Long storyId){service.deleteStory(id(p),storyId);return ResponseEntity.noContent().build();}
 @GetMapping("/stories/{storyId}/media") public ResponseEntity<Resource> storyMedia(Principal p,@PathVariable Long storyId){return resource(service.storyMedia(id(p),storyId));}
 private ResponseEntity<Resource> resource(SocialService.Attachment a){return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,"inline; filename=\""+(a.name()==null?"media":a.name().replace("\"",""))+"\"").contentType(MediaType.parseMediaType(a.type())).body(a.resource());} private Long id(Principal p){return Long.valueOf(p.getName());}
}
