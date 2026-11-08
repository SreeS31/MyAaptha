package com.myaaptha.platform.media;
import java.security.Principal;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api")
public class UploadPolicyController {
 private final UploadPolicyService policies;private final MediaAssetService assets;
 public UploadPolicyController(UploadPolicyService policies,MediaAssetService assets){this.policies=policies;this.assets=assets;}
 public record Usage(UploadPolicyService.Level level,long usedBytes,List<Integer> retentionDaysOptions,int defaultRetentionDays){}
 @GetMapping("/uploads/policy") public Usage mine(Principal principal){long id=Long.parseLong(principal.getName());return new Usage(policies.policy(id),assets.usage(id),UploadPolicyService.RETENTION_DAYS,0);}
 @GetMapping("/admin/upload-levels") public List<UploadPolicyService.Level> levels(){return policies.levels();}
 @PutMapping("/admin/upload-levels") public UploadPolicyService.Level save(@RequestBody UploadPolicyService.Level level){return policies.save(level);}
 public record Assignment(int levelId){}
 @PutMapping("/admin/upload-levels/users/{id}") public void assign(@PathVariable long id,@RequestBody Assignment assignment){policies.assign(id,assignment.levelId());}
}
