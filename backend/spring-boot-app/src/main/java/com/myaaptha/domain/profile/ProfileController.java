package com.myaaptha.domain.profile;
import java.security.Principal;
import org.springframework.web.bind.annotation.*;
import com.myaaptha.domain.profile.dto.UserProfileDto;
import org.springframework.core.io.Resource;
import org.springframework.http.*;
import org.springframework.web.multipart.MultipartFile;
@RestController @RequestMapping("/api/profile")
public class ProfileController {
 private final ProfileService service; private final ProfileMediaStorage storage; private final com.myaaptha.platform.media.MediaAssetService assets; public ProfileController(ProfileService service,ProfileMediaStorage storage,com.myaaptha.platform.media.MediaAssetService assets){this.service=service;this.storage=storage;this.assets=assets;}
 @GetMapping("/me") public UserProfileDto get(Principal p){return service.get(Long.valueOf(p.getName()));}
 @PutMapping("/me") public UserProfileDto save(Principal p,@RequestBody UserProfileDto d){return service.save(Long.valueOf(p.getName()),d);}
 @PostMapping(value="/me/photo",consumes=MediaType.MULTIPART_FORM_DATA_VALUE) public UserProfileDto photo(Principal p,@RequestPart("file") MultipartFile file){return service.uploadProfilePhoto(Long.valueOf(p.getName()),file);}
 @DeleteMapping("/me/photo") public UserProfileDto removePhoto(Principal p){return service.removeProfilePhoto(Long.valueOf(p.getName()));}
 @PostMapping(value="/me/photos",consumes=MediaType.MULTIPART_FORM_DATA_VALUE) public UserProfileDto gallery(Principal p,@RequestPart("file") MultipartFile file){return service.addGalleryPhoto(Long.valueOf(p.getName()),file);}
 @DeleteMapping("/me/photos/{index}") public UserProfileDto removeGallery(Principal p,@PathVariable int index){return service.removeGalleryPhoto(Long.valueOf(p.getName()),index);}
 @GetMapping("/media/{name}") public ResponseEntity<Resource> media(@PathVariable String name){Resource resource=storage.load(name);MediaType type=name.endsWith(".png")?MediaType.IMAGE_PNG:name.endsWith(".webp")?MediaType.parseMediaType("image/webp"):MediaType.IMAGE_JPEG;return ResponseEntity.ok().contentType(type).cacheControl(CacheControl.maxAge(java.time.Duration.ofDays(30)).cachePublic()).body(resource);}
 @GetMapping("/me/media-usage") public java.util.Map<String,Long> usage(Principal p){return java.util.Map.of("usedBytes",assets.usage(Long.valueOf(p.getName())));}
}
