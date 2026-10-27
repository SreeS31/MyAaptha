package com.myaaptha.domain.ai;

import jakarta.validation.Valid;
import java.security.Principal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai/preferences")
public class AiPreferenceController {
  private final AiPreferenceService service;

  public AiPreferenceController(AiPreferenceService service) { this.service = service; }

  @GetMapping
  public AiPreferenceService.AiPreferenceDto get(Principal principal) {
    return service.get(userId(principal));
  }

  @PutMapping
  public AiPreferenceService.AiPreferenceDto update(Principal principal,
      @Valid @RequestBody AiPreferenceService.UpdateAiPreferenceRequest request) {
    return service.update(userId(principal), request);
  }

  private Long userId(Principal principal) { return Long.valueOf(principal.getName()); }
}
