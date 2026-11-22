package com.myaaptha.domain.message;

import java.security.Principal;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/network/meetings")
public class CommunicationCallController {
  public record Start(@NotNull @Pattern(regexp="DIRECT|CIRCLE") String scope,@Positive long targetId,@NotNull @Pattern(regexp="AUDIO|VIDEO") String callType) {}
  public record Signal(@Positive long recipientId,@NotNull @Pattern(regexp="offer|answer|ice") String type,@NotBlank @Size(max=131072) String payload) {}
  private final CommunicationCallService calls;
  public CommunicationCallController(CommunicationCallService calls){this.calls=calls;}
  private long user(Principal p){return Long.parseLong(p.getName());}
  @PostMapping public CommunicationCallService.Room start(Principal p,@Valid @RequestBody Start input){return calls.start(user(p),input);}
  @GetMapping public List<CommunicationCallService.Room> active(Principal p){return calls.active(user(p));}
  @GetMapping("/history") public List<CommunicationCallService.Room> history(Principal p){return calls.history(user(p));}
  @GetMapping("/{roomKey}") public CommunicationCallService.Room get(Principal p,@PathVariable("roomKey") String id){return calls.get(user(p),id);}
  @PostMapping("/{roomKey}/join") public CommunicationCallService.Room join(Principal p,@PathVariable("roomKey") String id){return calls.join(user(p),id);}
  @PostMapping("/{roomKey}/leave") public void leave(Principal p,@PathVariable("roomKey") String id){calls.leave(user(p),id);}
  @PostMapping("/{roomKey}/end") public void end(Principal p,@PathVariable("roomKey") String id){calls.end(user(p),id);}
  @PostMapping("/{roomKey}/signals") public void signal(Principal p,@PathVariable("roomKey") String id,@Valid @RequestBody Signal input){calls.signal(user(p),id,input);}
  @GetMapping("/{roomKey}/signals") public List<CommunicationCallService.Envelope> signals(Principal p,@PathVariable("roomKey") String id,@RequestParam(defaultValue="0") @Min(0) long after){return calls.signals(user(p),id,after);}
}
