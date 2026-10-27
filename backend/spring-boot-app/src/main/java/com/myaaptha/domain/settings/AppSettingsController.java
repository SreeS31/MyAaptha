package com.myaaptha.domain.settings;
import java.security.Principal;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/settings/me")
public class AppSettingsController {
  private final AppSettingsService service;
  public AppSettingsController(AppSettingsService service){this.service=service;}
  @GetMapping public AppSettingsService.Settings get(Principal principal){return service.get(Long.valueOf(principal.getName()));}
  @PutMapping public AppSettingsService.Settings update(Principal principal,@Valid @RequestBody AppSettingsService.Settings settings){return service.update(Long.valueOf(principal.getName()),settings);}
}
