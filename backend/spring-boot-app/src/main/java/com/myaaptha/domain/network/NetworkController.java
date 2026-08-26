package com.myaaptha.domain.network;

import java.security.Principal;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.http.MediaType;
import org.springframework.http.HttpHeaders;
import org.springframework.core.io.Resource;
import com.myaaptha.domain.circle.CircleConversationService;
import com.myaaptha.domain.network.dto.CirclePostDto;
import com.myaaptha.domain.message.DirectMessageService;
import com.myaaptha.domain.network.dto.DirectMessageDto;
import com.myaaptha.domain.message.DirectCallService;
import com.myaaptha.domain.message.RelationshipBroadcastService;
import com.myaaptha.domain.network.dto.BroadcastAudienceDto;
import com.myaaptha.domain.network.dto.BroadcastResultDto;
import com.myaaptha.domain.network.dto.DirectCallDto;
import com.myaaptha.domain.network.dto.StartDirectCallRequest;
import com.myaaptha.domain.network.dto.AnswerDirectCallRequest;

import com.myaaptha.domain.network.dto.AddRelationshipRequest;
import com.myaaptha.domain.network.dto.AddPersonRequest;
import com.myaaptha.domain.network.dto.CircleMemberRequest;
import com.myaaptha.domain.network.dto.CreateNetworkCircleRequest;
import com.myaaptha.domain.network.dto.NetworkCircleDto;
import com.myaaptha.domain.network.dto.NetworkPersonDto;
import com.myaaptha.domain.network.dto.NetworkRelationshipDto;
import com.myaaptha.domain.network.dto.UpdateRelationshipRequest;
import com.myaaptha.domain.network.dto.UpdateNetworkCircleRequest;

@RestController
@RequestMapping("/api/network")
public class NetworkController {
  private final NetworkService networkService;
  private final CircleConversationService circleConversationService;
  private final DirectMessageService directMessageService;
  private final DirectCallService directCallService;
  private final RelationshipBroadcastService broadcastService;
  private final RelationshipBulkImportService bulkImportService;
  private final RelationshipImportTemplateService templateService;
  public NetworkController(NetworkService networkService,CircleConversationService circleConversationService,DirectMessageService directMessageService,DirectCallService directCallService,RelationshipBroadcastService broadcastService,RelationshipBulkImportService bulkImportService,RelationshipImportTemplateService templateService) { this.networkService = networkService; this.circleConversationService=circleConversationService; this.directMessageService=directMessageService; this.directCallService=directCallService; this.broadcastService=broadcastService; this.bulkImportService=bulkImportService; this.templateService=templateService; }

  @GetMapping("/search")
  public List<NetworkPersonDto> search(Principal principal, @RequestParam(defaultValue = "") String q) {
    return networkService.search(userId(principal), q);
  }

  @GetMapping("/relationships")
  public List<NetworkRelationshipDto> relationships(Principal principal) {
    return networkService.relationships(userId(principal));
  }

  @GetMapping("/relationship-types")
  public List<String> relationshipTypes() { return networkService.relationshipTypes(); }

  @PostMapping("/relationships")
  public NetworkRelationshipDto addRelationship(Principal principal, @RequestBody AddRelationshipRequest request) {
    return networkService.addRelationship(userId(principal), request);
  }

  @PostMapping("/relationships/add-person")
  public NetworkRelationshipDto addPerson(Principal principal, @RequestBody AddPersonRequest request) {
    return networkService.addPerson(userId(principal), request);
  }

  @PutMapping("/relationships/{id}")
  public NetworkRelationshipDto updateRelationship(Principal principal, @PathVariable Long id,
      @RequestBody UpdateRelationshipRequest request) {
    return networkService.updateRelationship(userId(principal), id, request);
  }

  @DeleteMapping("/relationships/{id}")
  public ResponseEntity<Void> removeRelationship(Principal principal, @PathVariable Long id) {
    networkService.removeRelationship(userId(principal), id);
    return ResponseEntity.noContent().build();
  }

  @PostMapping(value = "/relationships/bulk-import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public com.myaaptha.domain.network.dto.RelationshipImportResultDto bulkImport(Principal principal,
      @RequestPart("file") MultipartFile file) {
    return bulkImportService.importFile(userId(principal), file);
  }

  @GetMapping("/relationships/bulk-import/template")
  public ResponseEntity<Resource> bulkImportTemplate() {
    byte[] bytes = templateService.build();
    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"relationship_bulk_import_template.xlsx\"")
        .body(new org.springframework.core.io.ByteArrayResource(bytes));
  }

  @GetMapping("/circles")
  public List<NetworkCircleDto> circles(Principal principal) { return networkService.circles(userId(principal)); }

  @PostMapping("/circles")
  public NetworkCircleDto createCircle(Principal principal, @RequestBody CreateNetworkCircleRequest request) {
    return networkService.createCircle(userId(principal), request);
  }

  @PutMapping("/circles/{circleId}")
  public NetworkCircleDto updateCircle(Principal principal, @PathVariable Long circleId,
      @RequestBody UpdateNetworkCircleRequest request) {
    return networkService.updateCircle(userId(principal), circleId, request);
  }

  @PostMapping("/circles/{circleId}/members")
  public NetworkCircleDto addMember(Principal principal, @PathVariable Long circleId,
      @RequestBody CircleMemberRequest request) {
    return networkService.addCircleMember(userId(principal), circleId, request.userId());
  }

  @DeleteMapping("/circles/{circleId}/members/{userId}")
  public NetworkCircleDto removeMember(Principal principal, @PathVariable Long circleId, @PathVariable Long userId) {
    return networkService.removeCircleMember(userId(principal), circleId, userId);
  }

  @PostMapping("/circles/{circleId}/admins/{memberUserId}")
  public NetworkCircleDto promoteAdmin(Principal principal, @PathVariable Long circleId, @PathVariable Long memberUserId) {
    return networkService.promoteCircleAdmin(userId(principal), circleId, memberUserId);
  }

  @DeleteMapping("/circles/{circleId}/admins/{memberUserId}")
  public NetworkCircleDto demoteAdmin(Principal principal, @PathVariable Long circleId, @PathVariable Long memberUserId) {
    return networkService.demoteCircleAdmin(userId(principal), circleId, memberUserId);
  }

  @GetMapping("/circles/{circleId}/posts")
  public List<CirclePostDto> circlePosts(Principal principal,@PathVariable Long circleId){return circleConversationService.posts(userId(principal),circleId);}

  @GetMapping("/circles/unread-counts") public java.util.Map<Long,Long> circleUnreadCounts(Principal principal){return circleConversationService.unreadCounts(userId(principal));}

  @PostMapping(value="/circles/{circleId}/posts",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
  public CirclePostDto createCirclePost(Principal principal,@PathVariable Long circleId,
      @RequestParam(value="message",required=false) String message,@RequestParam(value="parentPostId",required=false) Long parentPostId,
      @RequestPart(value="file",required=false) MultipartFile file){return circleConversationService.create(userId(principal),circleId,parentPostId,message,file);}

  @PutMapping("/circles/{circleId}/posts/{postId}") public CirclePostDto editCirclePost(Principal principal,@PathVariable Long circleId,@PathVariable Long postId,@RequestBody MessageTextRequest request){return circleConversationService.edit(userId(principal),circleId,postId,request.message());}
  @DeleteMapping("/circles/{circleId}/posts/{postId}") public CirclePostDto deleteCirclePost(Principal principal,@PathVariable Long circleId,@PathVariable Long postId){return circleConversationService.delete(userId(principal),circleId,postId);}
  @GetMapping("/circles/{circleId}/posts/search") public List<CirclePostDto> searchCirclePosts(Principal principal,@PathVariable Long circleId,@RequestParam String q){return circleConversationService.search(userId(principal),circleId,q);}
  @PostMapping("/circles/{circleId}/posts/{postId}/reaction") public CirclePostDto reactCirclePost(Principal principal,@PathVariable Long circleId,@PathVariable Long postId,@RequestBody MessageReactionRequest request){return circleConversationService.react(userId(principal),circleId,postId,request.emoji());}

  @GetMapping("/circles/{circleId}/posts/{postId}/attachment")
  public ResponseEntity<Resource> circleAttachment(Principal principal,@PathVariable Long circleId,@PathVariable Long postId){var attachment=circleConversationService.attachment(userId(principal),circleId,postId);return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,"inline; filename=\""+attachment.name().replace("\"","")+"\"").contentType(MediaType.parseMediaType(attachment.type())).body(attachment.resource());}

  @GetMapping("/messages/with/{otherUserId}")
  public List<DirectMessageDto> directMessages(Principal principal,@PathVariable Long otherUserId){return directMessageService.conversation(userId(principal),otherUserId);}

  @GetMapping("/messages/conversations")
  public java.util.List<com.myaaptha.domain.network.dto.DirectConversationDto> directConversations(Principal principal){return directMessageService.conversations(userId(principal));}

  @GetMapping("/messages/with/{otherUserId}/search")
  public List<DirectMessageDto> searchDirectMessages(Principal principal,@PathVariable Long otherUserId,@RequestParam String q){return directMessageService.search(userId(principal),otherUserId,q);}

  @PostMapping(value="/messages/with/{otherUserId}",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
  public DirectMessageDto sendDirectMessage(Principal principal,@PathVariable Long otherUserId,@RequestParam(value="message",required=false) String message,@RequestParam(value="replyToMessageId",required=false) Long replyToMessageId,@RequestPart(value="file",required=false) MultipartFile file){return directMessageService.send(userId(principal),otherUserId,message,file,replyToMessageId);}

  @PutMapping("/messages/with/{otherUserId}/{messageId}")
  public DirectMessageDto editDirectMessage(Principal principal,@PathVariable Long otherUserId,@PathVariable Long messageId,@RequestBody MessageTextRequest request){return directMessageService.edit(userId(principal),otherUserId,messageId,request.message());}

  @DeleteMapping("/messages/with/{otherUserId}/{messageId}")
  public DirectMessageDto deleteDirectMessage(Principal principal,@PathVariable Long otherUserId,@PathVariable Long messageId){return directMessageService.delete(userId(principal),otherUserId,messageId);}

  @PostMapping("/messages/with/{otherUserId}/{messageId}/reaction")
  public DirectMessageDto reactDirectMessage(Principal principal,@PathVariable Long otherUserId,@PathVariable Long messageId,@RequestBody MessageReactionRequest request){return directMessageService.react(userId(principal),otherUserId,messageId,request.emoji());}

  @GetMapping("/messages/with/{otherUserId}/{messageId}/attachment")
  public ResponseEntity<Resource> directMessageAttachment(Principal principal,@PathVariable Long otherUserId,@PathVariable Long messageId){var attachment=directMessageService.attachment(userId(principal),otherUserId,messageId);return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,"inline; filename=\""+attachment.name().replace("\"","")+"\"").contentType(MediaType.parseMediaType(attachment.type())).body(attachment.resource());}

  @PostMapping("/calls") public DirectCallDto startCall(Principal principal,@RequestBody StartDirectCallRequest request){return directCallService.start(userId(principal),request);}
  @GetMapping("/calls/incoming") public List<DirectCallDto> incomingCalls(Principal principal){return directCallService.incoming(userId(principal));}
  @GetMapping("/calls/{callId}") public DirectCallDto call(Principal principal,@PathVariable Long callId){return directCallService.get(userId(principal),callId);}
  @PostMapping("/calls/{callId}/accept") public DirectCallDto acceptCall(Principal principal,@PathVariable Long callId,@RequestBody AnswerDirectCallRequest request){return directCallService.accept(userId(principal),callId,request.answerSdp());}
  @PostMapping("/calls/{callId}/reject") public DirectCallDto rejectCall(Principal principal,@PathVariable Long callId){return directCallService.reject(userId(principal),callId);}
  @PostMapping("/calls/{callId}/end") public DirectCallDto endCall(Principal principal,@PathVariable Long callId){return directCallService.end(userId(principal),callId);}

  @GetMapping("/broadcasts/preview")
  public BroadcastAudienceDto previewBroadcast(Principal principal,
      @RequestParam(required=false) String audienceType,
      @RequestParam(name="type",required=false) String legacyAudienceType,
      @RequestParam(required=false) Long anchorUserId,
      @RequestParam(required=false) String location) {
    return broadcastService.preview(userId(principal), audienceType == null ? legacyAudienceType : audienceType, anchorUserId, location);
  }

  @PostMapping(value="/broadcasts", consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
  public BroadcastResultDto sendBroadcast(Principal principal,
      @RequestParam(required=false) String audienceType,
      @RequestParam(name="type",required=false) String legacyAudienceType,
      @RequestParam(required=false) Long anchorUserId,
      @RequestParam(required=false) String location,
      @RequestParam(value="message",required=false) String message,
      @RequestPart(value="file",required=false) MultipartFile file) {
    return broadcastService.send(userId(principal), audienceType == null ? legacyAudienceType : audienceType, anchorUserId, location, message, file);
  }

  private Long userId(Principal principal) { return Long.valueOf(principal.getName()); }
  public record MessageTextRequest(String message) {}
  public record MessageReactionRequest(String emoji) {}
}
