package com.myaaptha.domain.ai;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.security.Principal;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai/approvals")
public class AiActionApprovalController {
  private final AiActionApprovalService service;

  public AiActionApprovalController(AiActionApprovalService service) { this.service = service; }

  @GetMapping
  public List<AiActionApprovalService.AiActionApprovalDto> recent(Principal principal) {
    return service.recent(userId(principal));
  }

  @PutMapping("/{approvalId}/decision")
  public AiActionApprovalService.AiActionApprovalDto decide(Principal principal,
      @PathVariable UUID approvalId, @Valid @RequestBody DecisionRequest request) {
    return service.decide(userId(principal), approvalId, request.decision(), request.reason());
  }

  public record DecisionRequest(
      @NotNull @Pattern(regexp = "APPROVED|REJECTED") String decision,
      @Size(max = 240) String reason) {}

  private Long userId(Principal principal) { return Long.valueOf(principal.getName()); }
}
