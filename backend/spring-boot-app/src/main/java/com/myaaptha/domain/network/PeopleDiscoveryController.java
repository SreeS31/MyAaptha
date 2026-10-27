package com.myaaptha.domain.network;
import java.security.Principal;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/network/discover")
public class PeopleDiscoveryController {
  private final PeopleDiscoveryService service;
  public PeopleDiscoveryController(PeopleDiscoveryService service){this.service=service;}
  @GetMapping public PeopleDiscoveryService.Result search(Principal principal,@RequestParam String q){return service.search(Long.valueOf(principal.getName()),q);}
}
