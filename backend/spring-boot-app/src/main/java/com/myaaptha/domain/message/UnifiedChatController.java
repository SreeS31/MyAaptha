package com.myaaptha.domain.message;

import com.myaaptha.domain.circle.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/network/chats")
public class UnifiedChatController {
  public enum Kind { DIRECT, CIRCLE }
  public record Target(@NotNull Kind type,@NotNull @Positive Long id) {}
  public record Forward(@NotNull Kind sourceType,@NotNull @Positive Long conversationId,
      @NotNull @Positive Long messageId,@NotNull @Size(min=1,max=10) List<@NotNull @Valid Target> targets) {}
  public record CircleChat(Long circleId,String displayName,String lastMessage,Instant lastMessageAt,long unreadCount) {}
  private final DirectMessageService direct;
  private final CircleConversationService circle;
  private final CircleRepository circles;
  private final CirclePostRepository posts;
  public UnifiedChatController(DirectMessageService direct,CircleConversationService circle,CircleRepository circles,CirclePostRepository posts){this.direct=direct;this.circle=circle;this.circles=circles;this.posts=posts;}

  // A preview never calls the conversation reader, which would acknowledge messages.
  @GetMapping("/circles") @Transactional(readOnly=true)
  public List<CircleChat> circleChats(Principal principal){
    Long user=id(principal);var unread=circle.unreadCounts(user);
    var latest=new HashMap<Long,com.myaaptha.domain.circle.model.CirclePostEntity>();
    posts.latestConversations(user).forEach(post->latest.put(post.getCircleId(),post));
    return circles.findVisibleToUser(user).stream().filter(c->c.getMemberUserIds().contains(user)).map(c->{
      var post=latest.get(c.getId());
      String preview=post==null?"No messages yet":post.getDeletedAt()!=null?"Message deleted":!post.getMessage().isBlank()?post.getMessage():Objects.requireNonNullElse(post.getAttachmentName(),"Attachment");
      return new CircleChat(c.getId(),c.getName(),preview,post==null?null:post.getCreatedAt(),unread.getOrDefault(c.getId(),0L));
    }).sorted(Comparator.comparing(CircleChat::lastMessageAt,Comparator.nullsLast(Comparator.reverseOrder()))).toList();
  }
  @PutMapping("/circles/{circleId}/{messageId}/flags")
  public Object flags(Principal principal,@PathVariable Long circleId,@PathVariable Long messageId,@RequestBody MessagePersonalizationController.Flags flags){return circle.flags(id(principal),circleId,messageId,flags.starred(),flags.pinned());}

  @PostMapping("/forward") @Transactional
  public Map<String,Integer> forward(Principal principal,@Valid @RequestBody Forward value){
    Long user=id(principal);
    if(new HashSet<>(value.targets()).size()!=value.targets().size())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose each destination only once");
    // Check every destination before creating any copies. One invalid target rejects the batch.
    for(var target:value.targets()){
      if(target.type()==Kind.DIRECT)direct.validateRecipient(user,target.id());
      else circle.validateRecipient(user,target.id());
    }
    String text;MultipartFile file=null;
    if(value.sourceType()==Kind.DIRECT){
      var source=direct.forwardSource(user,value.conversationId(),value.messageId());text=source.message();
      if(source.attachmentUrl()!=null){var attachment=direct.attachment(user,value.conversationId(),value.messageId());file=copy(attachment.resource(),attachment.name(),attachment.type());}
    }else{
      var source=circle.forwardSource(user,value.conversationId(),value.messageId());text=source.message();
      if(source.attachmentUrl()!=null){var attachment=circle.attachment(user,value.conversationId(),value.messageId());file=copy(attachment.resource(),attachment.name(),attachment.type());}
    }
    for(var target:value.targets()){
      if(target.type()==Kind.DIRECT){var sent=direct.send(user,target.id(),text,file,null);direct.markForwarded(sent.id());}
      else{var sent=circle.create(user,target.id(),null,text,file);circle.markForwarded(sent.id());}
    }
    return Map.of("sent",value.targets().size());
  }
  private MultipartFile copy(org.springframework.core.io.Resource resource,String name,String type){
    try(var input=resource.getInputStream()){
      byte[] bytes=input.readNBytes(25*1024*1024+1);
      if(bytes.length>25*1024*1024)throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"Attachment exceeds the forwarding limit");
      return new ForwardedAttachment(name,type,bytes);
    }catch(java.io.IOException exception){throw new ResponseStatusException(HttpStatus.CONFLICT,"The original attachment is no longer available");}
  }
  private Long id(Principal principal){return Long.valueOf(principal.getName());}
}
