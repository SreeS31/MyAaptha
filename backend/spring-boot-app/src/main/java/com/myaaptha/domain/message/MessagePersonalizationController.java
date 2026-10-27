package com.myaaptha.domain.message;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.util.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/network/messages")
public class MessagePersonalizationController {
  private final DirectMessageService messages;
  private final MessagePersonalization preferences;
  public MessagePersonalizationController(DirectMessageService messages,MessagePersonalization preferences){this.messages=messages;this.preferences=preferences;}
  public record Forward(@NotNull @Positive Long recipientId) {}
  @PostMapping("/with/{other}/{message}/forward")
  public Object forward(Principal p,@PathVariable Long other,@PathVariable Long message,@Valid @RequestBody Forward value) {return messages.forward(id(p),other,message,value.recipientId());}
  public record Flags(Boolean starred,Boolean pinned) {}
  public record Receipt(@NotNull @Size(min=1,max=100) List<@NotNull @Positive Long> messageIds) {}
  public record Pin(@NotNull Boolean pinned) {}
  public record ChatSettings(Boolean archived,Boolean muted,Boolean markedUnread) {}
  public record Preferences(@NotNull Boolean readReceipts) {}
  @PutMapping("/with/{other}/{message}/flags")
  public Object flags(Principal p,@PathVariable Long other,@PathVariable Long message,@RequestBody Flags value) {return messages.flags(id(p),other,message,value.starred(),value.pinned());}
  @GetMapping("/with/{other}/saved")
  public Object saved(Principal p,@PathVariable Long other,@RequestParam String kind,@RequestParam(defaultValue="9223372036854775807") Long beforeId,@RequestParam(defaultValue="50") int limit) {return messages.saved(id(p),other,kind,beforeId,limit);}
  @PostMapping("/with/{other}/read")
  public void read(Principal p,@PathVariable Long other,@Valid @RequestBody Receipt value) {messages.acknowledgeRead(id(p),other,value.messageIds());}
  @PutMapping("/with/{other}/pin")
  public void pin(Principal p,@PathVariable Long other,@Valid @RequestBody Pin value) {messages.pinChat(id(p),other,value.pinned());}
  @PutMapping("/with/{other}/settings")
  public void chatSettings(Principal p,@PathVariable Long other,@RequestBody ChatSettings value) {
    messages.chatSettings(id(p),other,value.archived(),value.muted(),value.markedUnread());
  }
  @GetMapping("/preferences")
  public Preferences preferences(Principal p) {return new Preferences(preferences.readReceipts(id(p)));}
  @PutMapping("/preferences")
  public Preferences preferences(Principal p,@Valid @RequestBody Preferences value) {preferences.setReadReceipts(id(p),value.readReceipts());return value;}
  private Long id(Principal p){return Long.valueOf(p.getName());}
}
