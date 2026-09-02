package com.myaaptha.domain.ai;

import java.security.Principal;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/ai")
public class AiAssistantController {
  private final RestClient client;
  private final AiActionLedgerService ledger;

  public AiAssistantController(RestClient.Builder builder, AiActionLedgerService ledger,
      @Value("${myaaptha.ai.base-url:http://localhost:8081/api/v1}") String baseUrl) {
    this.client = builder.baseUrl(baseUrl).build();
    this.ledger = ledger;
  }

  @PostMapping("/search/rank")
  public Object rank(Principal principal, @RequestBody Map<String, Object> request) {
    return execute(principal, "SEARCH_RANKING", "L0", "Rank authorized search results", false,
        "NOT_REQUIRED", "/search/rank", request);
  }

  @PostMapping("/duplicates")
  public Object duplicates(Principal principal, @RequestBody Map<String, Object> request) {
    return execute(principal, "DUPLICATE_DETECTION", "L1", "Suggest duplicate people for review",
        false, "NOT_REQUIRED", "/duplicates", request);
  }

  @PostMapping("/family/insights")
  public Object insights(Principal principal, @RequestBody Map<String, Object> request) {
    requireConsent(request);
    return execute(principal, "FAMILY_INSIGHTS", "L1", "Suggest relationship graph improvements",
        true, "APPROVED", "/family/insights", request);
  }

  @PostMapping("/profiles/enrichment")
  public Object enrichment(Principal principal, @RequestBody Map<String, Object> request) {
    requireConsent(request);
    return execute(principal, "PROFILE_ENRICHMENT", "L1", "Suggest profile fields for review",
        true, "APPROVED", "/profiles/enrichment", request);
  }

  @PostMapping("/contacts/organize")
  public Object organizeContacts(Principal principal, @RequestBody Map<String, Object> request) {
    requireConsent(request);
    return execute(principal, "CONTACT_ORGANIZATION", "L1",
        "Suggest relationships and circles from selected contacts", true, "APPROVED",
        "/contacts/organize", request);
  }

  @GetMapping("/activity")
  public List<AiActionLedgerService.AiActionEventDto> activity(Principal principal) {
    return ledger.recent(userId(principal));
  }

  private Object execute(Principal principal, String capability, String actionLevel,
      String purpose, boolean consent, String approvalState, String path,
      Map<String, Object> request) {
    AiActionEventEntity event = ledger.start(userId(principal), capability, actionLevel,
        purpose, consent, approvalState);
    try {
      Object response = client.post().uri(path).body(request).retrieve().body(Object.class);
      ledger.succeeded(event);
      return response;
    } catch (Exception exception) {
      ledger.failed(event, "AI_SERVICE_UNAVAILABLE");
      throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
          "AI assistance is temporarily unavailable. Your data was not changed.");
    }
  }

  private void requireConsent(Map<String, Object> request) {
    if (!Boolean.TRUE.equals(request.get("consent"))) {
      throw new ResponseStatusException(HttpStatus.FORBIDDEN,
          "Explicit consent is required for this AI feature");
    }
  }

  private Long userId(Principal principal) { return Long.valueOf(principal.getName()); }
}
