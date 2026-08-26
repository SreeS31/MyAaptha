package com.myaaptha.domain.presence;

import java.security.Principal;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/network/presence")
public class PresenceController {
  private final PresenceService service;
  public PresenceController(PresenceService service) { this.service = service; }
  @PostMapping("/heartbeat") public void heartbeat(Principal principal) { service.heartbeat(id(principal)); }
  @GetMapping("/direct/{userId}") public PresenceDto direct(Principal principal, @PathVariable Long userId) { return service.direct(id(principal), userId); }
  @PostMapping("/direct/{userId}/typing") public void directTyping(Principal principal, @PathVariable Long userId, @RequestBody TypingRequest request) { service.typeDirect(id(principal), userId, request.typing()); }
  @GetMapping("/circles/{circleId}") public PresenceDto circle(Principal principal, @PathVariable Long circleId) { return service.circle(id(principal), circleId); }
  @PostMapping("/circles/{circleId}/typing") public void circleTyping(Principal principal, @PathVariable Long circleId, @RequestBody TypingRequest request) { service.typeCircle(id(principal), circleId, request.typing()); }
  private Long id(Principal principal) { return Long.valueOf(principal.getName()); }
  public record TypingRequest(boolean typing) {}
}
