package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.dto.DeviceTokenRequest;
import com.myaaptha.domain.notification.dto.NotificationDto;
import com.myaaptha.domain.notification.dto.NotificationPreferenceDto;
import com.myaaptha.domain.notification.dto.UpdateNotificationPreferenceRequest;
import jakarta.validation.Valid;
import java.security.Principal;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
  private final NotificationService service;
  public NotificationController(NotificationService service){this.service=service;}
  @GetMapping public List<NotificationDto> inbox(Principal principal){return service.inbox(userId(principal));}
  @GetMapping("/unread-count") public Map<String,Long> unreadCount(Principal principal){return Map.of("count",service.unreadCount(userId(principal)));}
  @PostMapping("/{id}/read") public NotificationDto read(Principal principal,@PathVariable Long id){return service.markRead(userId(principal),id);}
  @PostMapping("/read-all") public ResponseEntity<Void> readAll(Principal principal){service.markAllRead(userId(principal));return ResponseEntity.noContent().build();}
  @GetMapping("/preferences") public NotificationPreferenceDto preferences(Principal principal){return service.preferences(userId(principal));}
  @PutMapping("/preferences") public NotificationPreferenceDto updatePreferences(Principal principal,@RequestBody UpdateNotificationPreferenceRequest request){return service.updatePreferences(userId(principal),request);}
  @PostMapping("/devices") public ResponseEntity<Void> registerDevice(Principal principal,@Valid @RequestBody DeviceTokenRequest request){service.registerDevice(userId(principal),request);return ResponseEntity.noContent().build();}
  @DeleteMapping("/devices") public ResponseEntity<Void> unregisterDevice(Principal principal,@RequestParam String token){service.unregisterDevice(userId(principal),token);return ResponseEntity.noContent().build();}
  @GetMapping("/unsubscribe/{token}") public Map<String,String> unsubscribe(@PathVariable String token){service.unsubscribe(token);return Map.of("message","External notifications have been disabled.");}
  private Long userId(Principal principal){return Long.valueOf(principal.getName());}
}
