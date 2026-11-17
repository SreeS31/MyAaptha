package com.myaaptha.domain.interests;
import java.security.Principal;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/interests")
public class InterestGroupController {
    private final InterestGroupService service;
    public InterestGroupController(InterestGroupService service){this.service=service;}
    public record Selection(List<String> interests){}
    public record Decision(boolean approve){}
    public record Message(String body){}
    @GetMapping("/me") public List<String> interests(Principal p){return service.interests(id(p));}
    @PutMapping("/me") public List<String> save(Principal p,@RequestBody Selection body){return service.saveInterests(id(p),body.interests());}
    @GetMapping("/groups") public InterestGroupService.Page<InterestGroupService.Group> groups(Principal p,@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="") String area,@RequestParam(defaultValue="") String topic,@RequestParam(defaultValue="false") boolean mine,@RequestParam(defaultValue="0") int page){return service.directory(id(p),q,area,topic,mine,page);}
    @PostMapping("/groups") public InterestGroupService.Group create(Principal p,@RequestBody InterestGroupService.GroupInput body){return service.create(id(p),body);}
    @GetMapping("/groups/{group}") public InterestGroupService.Group group(Principal p,@PathVariable String group){return service.detail(id(p),group);}
    @PutMapping("/groups/{group}") public InterestGroupService.Group edit(Principal p,@PathVariable String group,@RequestBody InterestGroupService.GroupInput body){return service.edit(id(p),group,body);}
    @PostMapping("/groups/{group}/join") public InterestGroupService.Group join(Principal p,@PathVariable String group){return service.request(id(p),group);}
    @DeleteMapping("/groups/{group}/membership") public InterestGroupService.Group leave(Principal p,@PathVariable String group){return service.leave(id(p),group);}
    @GetMapping("/groups/{group}/requests") public InterestGroupService.Page<InterestGroupService.Member> requests(Principal p,@PathVariable String group,@RequestParam(defaultValue="0") int page){return service.requests(id(p),group,page);}
    @PutMapping("/groups/{group}/requests/{member}") public void decide(Principal p,@PathVariable String group,@PathVariable long member,@RequestBody Decision body){service.decide(id(p),group,member,body.approve());}
    @GetMapping("/groups/{group}/messages") public InterestGroupService.Page<InterestGroupService.Discussion> messages(Principal p,@PathVariable String group,@RequestParam(defaultValue="0") int page){return service.messages(id(p),group,page);}
    @PostMapping("/groups/{group}/messages") public void post(Principal p,@PathVariable String group,@RequestBody Message body){service.post(id(p),group,body.body());}
    @DeleteMapping("/groups/{group}/messages/{message}") public void delete(Principal p,@PathVariable String group,@PathVariable String message){service.deleteMessage(id(p),group,message);}
    private long id(Principal p){return Long.parseLong(p.getName());}
}
