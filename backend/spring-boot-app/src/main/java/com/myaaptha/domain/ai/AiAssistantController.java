package com.myaaptha.domain.ai;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/ai")
public class AiAssistantController {
  private final RestClient client;
  public AiAssistantController(RestClient.Builder builder,@Value("${myaaptha.ai.base-url:http://localhost:8081/api/v1}") String baseUrl){client=builder.baseUrl(baseUrl).build();}
  @PostMapping("/search/rank") public Object rank(@RequestBody Map<String,Object> request){return post("/search/rank",request);}
  @PostMapping("/duplicates") public Object duplicates(@RequestBody Map<String,Object> request){return post("/duplicates",request);}
  @PostMapping("/family/insights") public Object insights(@RequestBody Map<String,Object> request){consent(request);return post("/family/insights",request);}
  @PostMapping("/profiles/enrichment") public Object enrichment(@RequestBody Map<String,Object> request){consent(request);return post("/profiles/enrichment",request);}
  @PostMapping("/contacts/organize") public Object organizeContacts(@RequestBody Map<String,Object> request){consent(request);return post("/contacts/organize",request);}
  private void consent(Map<String,Object> request){if(!Boolean.TRUE.equals(request.get("consent")))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Explicit consent is required for this AI feature");}
  private Object post(String path,Map<String,Object> request){try{return client.post().uri(path).body(request).retrieve().body(Object.class);}catch(Exception e){throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"AI assistance is temporarily unavailable. Your data was not changed.");}}
}
