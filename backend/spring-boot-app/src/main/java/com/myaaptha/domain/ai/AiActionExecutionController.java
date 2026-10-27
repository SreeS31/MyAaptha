package com.myaaptha.domain.ai;

import java.security.Principal;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai/executions")
public class AiActionExecutionController {
  private final AiActionExecutionService service;

  public AiActionExecutionController(AiActionExecutionService service) { this.service = service; }

  @GetMapping
  public List<AiActionExecutionService.AiActionExecutionDto> recent(Principal principal) {
    return service.recent(Long.valueOf(principal.getName()));
  }
}
