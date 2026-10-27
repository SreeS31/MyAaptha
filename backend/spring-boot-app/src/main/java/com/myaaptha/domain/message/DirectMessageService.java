package com.myaaptha.domain.message;

import com.myaaptha.domain.circle.CircleMediaStorage;
import com.myaaptha.domain.message.model.DirectMessageEntity;
import com.myaaptha.domain.network.dto.DirectMessageDto;
import com.myaaptha.domain.network.dto.DirectConversationDto;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.notification.NotificationCommand;
import com.myaaptha.domain.notification.NotificationService;
import com.myaaptha.domain.privacy.UserBlockRepository;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.LinkedHashMap;
import java.time.Instant;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service @Transactional
public class DirectMessageService {
  private final DirectMessageRepository messages; private final UserRepository users;
  private final RelationshipRepository relationships; private final UserProfileRepository profiles;
  private final CircleMediaStorage storage;
  private final NotificationService notificationService;
  private final UserBlockRepository blocks;
  private final DirectMessageReactionRepository reactions;
  private final MessagePersonalization personalization;
  private static final Set<String> ALLOWED_REACTIONS=Set.of("👍","❤️","😂","😮","😢","🙏");
  public DirectMessageService(DirectMessageRepository messages,UserRepository users,RelationshipRepository relationships,UserProfileRepository profiles,CircleMediaStorage storage,NotificationService notificationService,UserBlockRepository blocks,DirectMessageReactionRepository reactions,MessagePersonalization personalization){this.messages=messages;this.users=users;this.relationships=relationships;this.profiles=profiles;this.storage=storage;this.notificationService=notificationService;this.blocks=blocks;this.reactions=reactions;this.personalization=personalization;}

  public List<DirectMessageDto> conversation(Long currentUserId,Long otherUserId){return conversation(currentUserId,otherUserId,Long.MAX_VALUE,50);}
  public List<DirectMessageDto> conversation(Long currentUserId,Long otherUserId,Long before,int limit){assertConversationParticipant(currentUserId,otherUserId);var conversation=new java.util.ArrayList<>(messages.page(currentUserId,otherUserId,before,org.springframework.data.domain.PageRequest.of(0,pageSize(limit))));java.util.Collections.reverse(conversation);var now=java.time.Instant.now();conversation.stream().filter(message->currentUserId.equals(message.getRecipientUserId())&&message.getReadAt()==null&&!message.hiddenFor(currentUserId)).forEach(message->{if(message.getDeliveredAt()==null)message.setDeliveredAt(now);});messages.saveAll(conversation);return pageDtos(conversation,currentUserId);}

  @Transactional(readOnly=true) public List<DirectConversationDto> conversations(Long userId){users.findById(userId).orElseThrow();var all=messages.latestConversations(userId);var pins=personalization.pinnedChats(userId);var settings=personalization.chatSettings(userId);Map<Long,DirectMessageEntity> latest=new LinkedHashMap<>();Map<Long,Long> unread=new java.util.HashMap<>();for(var row:messages.unreadCounts(userId))unread.put(row.getSenderId(),row.getUnreadCount());for(var message:all){Long other=userId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId();latest.putIfAbsent(other,message);}return latest.entrySet().stream().map(entry->{UserEntity other=users.findById(entry.getKey()).orElseThrow();DirectMessageEntity message=entry.getValue();String preview=message.getDeletedAt()!=null?"Message deleted":message.getMessage()!=null&&!message.getMessage().isBlank()?message.getMessage():message.getAttachmentName()!=null?message.getAttachmentName():"Attachment";return new DirectConversationDto(other.getId(),name(other),photo(other),preview,message.getCreatedAt(),unread.getOrDefault(other.getId(),0L),pins.contains(other.getId()),settings.getOrDefault(other.getId(),MessagePersonalization.DEFAULT_CHAT).archived(),settings.getOrDefault(other.getId(),MessagePersonalization.DEFAULT_CHAT).muted(),settings.getOrDefault(other.getId(),MessagePersonalization.DEFAULT_CHAT).markedUnread());}).sorted(java.util.Comparator.comparing(DirectConversationDto::pinned).reversed()).toList();}

  public DirectMessageDto send(Long senderId,Long recipientId,String message,MultipartFile file,Long replyToMessageId){
    validateRecipient(senderId,recipientId);
    String clean=message==null?"":message.trim();
    if(clean.length()>4000)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Message must be 4000 characters or less");
    if(clean.isBlank()&&(file==null||file.isEmpty()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Write a message or choose a file");
    DirectMessageEntity directMessage=new DirectMessageEntity();directMessage.setSenderUserId(senderId);directMessage.setRecipientUserId(recipientId);directMessage.setMessage(clean);
    if(replyToMessageId!=null){DirectMessageEntity reply=participantMessage(senderId,recipientId,replyToMessageId);if(reply.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"The replied message was deleted");directMessage.setReplyToMessageId(replyToMessageId);}
    if(file!=null&&!file.isEmpty()){var media=storage.store(senderId,file);directMessage.setAttachmentKey(media.key());directMessage.setAttachmentName(media.name());directMessage.setAttachmentType(media.type());directMessage.setAttachmentSize(media.size());}
    DirectMessageEntity saved=messages.save(directMessage); UserEntity sender=users.findById(senderId).orElseThrow();
    if(!personalization.muted(recipientId,senderId)) notificationService.notify(new NotificationCommand(recipientId,"DIRECT_MESSAGE","New message from "+name(sender),clean.isBlank()?"Sent an attachment":clean,"/dashboard?messageUserId="+senderId,"DIRECT_MESSAGE",saved.getId()));
    return dto(saved,senderId);
  }
  public DirectMessageDto send(Long senderId,Long recipientId,String message,MultipartFile file){return send(senderId,recipientId,message,file,null);}

  public void validateRecipient(Long senderId,Long recipientId){
    UserEntity recipient=assertConversationParticipant(senderId,recipientId);
    if(blocks.blockedEitherWay(senderId,recipientId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Messaging is unavailable for this account");
    if(!"ACTIVE".equals(recipient.getAccountStatus())||"MANAGED".equals(recipient.getIdentityType()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"This person does not have an active MyAaptha account and cannot receive private messages");
    if(relationships.findByOwnerUserIdAndRelatedUserId(senderId,recipientId).isEmpty()&&messages.page(senderId,recipientId,Long.MAX_VALUE,org.springframework.data.domain.PageRequest.of(0,1)).isEmpty())throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Add this person to your relationships before sending a private message");
  }
  public DirectMessageDto forwardSource(Long user,Long other,Long id){
    var source=participantMessage(user,other,id);
    if(source.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot be forwarded");
    return dto(source,user);
  }
  public void markForwarded(Long id){messages.findById(id).orElseThrow().setForwarded(true);}
  public DirectMessageDto forward(Long user,Long other,Long id,Long recipient) {
    var source=participantMessage(user,other,id);
    if(source.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot be forwarded");
    MultipartFile attachment=null;
    if(source.getAttachmentKey()!=null) {
      try(var input=storage.load(source.getAttachmentKey()).getInputStream()) {
        byte[] bytes=input.readNBytes(25*1024*1024+1);
        if(bytes.length>25*1024*1024)throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"Attachment exceeds the forwarding limit");
        attachment=new ForwardedAttachment(source.getAttachmentName(),source.getAttachmentType(),bytes);
      }catch(java.io.IOException e){throw new ResponseStatusException(HttpStatus.CONFLICT,"The original attachment is no longer available");}
    }
    var sent=send(user,recipient,source.getMessage(),attachment,null);
    var forwarded=messages.findById(sent.id()).orElseThrow();
    forwarded.setForwarded(true);
    return dto(messages.save(forwarded),user);
  }
  public DirectMessageDto edit(Long userId,Long otherUserId,Long messageId,String value){DirectMessageEntity message=participantMessage(userId,otherUserId,messageId);if(!userId.equals(message.getSenderUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only the sender can edit this message");if(message.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot be edited");String clean=value==null?"":value.trim();if(clean.length()>4000)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Message must be 4000 characters or less");if(clean.isBlank()&&message.getAttachmentKey()==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"A message cannot be empty");message.setMessage(clean);message.setEditedAt(Instant.now());return dto(messages.save(message),userId);}
  public DirectMessageDto delete(Long userId,Long otherUserId,Long messageId){DirectMessageEntity message=lockedParticipant(userId,otherUserId,messageId);if(!userId.equals(message.getSenderUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only the sender can delete for all");if(message.getDeletedAt()==null){if(!canDeleteForAll(message,userId))throw new ResponseStatusException(HttpStatus.CONFLICT,"Delete for all is available only before the recipient reads it and within 24 hours");if(message.getAttachmentKey()!=null)storage.delete(message.getAttachmentKey());message.setAttachmentKey(null);message.setAttachmentName(null);message.setAttachmentType(null);message.setAttachmentSize(null);message.setMessage("");message.setDeletedAt(Instant.now());}return dto(messages.save(message),userId);}
  private boolean canDeleteForAll(DirectMessageEntity message,Long user){return user.equals(message.getSenderUserId())&&message.getDeletedAt()==null&&message.getReadAt()==null&&message.getCreatedAt().plus(java.time.Duration.ofHours(24)).isAfter(Instant.now());}
  private DirectMessageEntity lockedParticipant(Long user,Long other,Long id){messages.locked(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"));return participantMessage(user,other,id);}
  public void deleteForMe(Long user,Long other,Long id){var message=lockedParticipant(user,other,id);message.hideFor(user);messages.save(message);}
  public DirectMessageDto react(Long userId,Long otherUserId,Long messageId,String emoji){if(blocks.blockedEitherWay(userId,otherUserId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Messaging is unavailable for this account");DirectMessageEntity message=participantMessage(userId,otherUserId,messageId);if(message.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot receive reactions");String clean=emoji==null?"":emoji.trim();if(!clean.isEmpty()&&!ALLOWED_REACTIONS.contains(clean))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a supported reaction");var existing=reactions.findByMessageIdAndUserId(messageId,userId);if(clean.isEmpty())existing.ifPresent(reactions::delete);else if(existing.isPresent()){existing.get().setEmoji(clean);reactions.save(existing.get());}else{var reaction=new com.myaaptha.domain.message.model.DirectMessageReactionEntity();reaction.setMessageId(messageId);reaction.setUserId(userId);reaction.setEmoji(clean);reactions.save(reaction);}return dto(message,userId);}
  @Transactional(readOnly=true) public List<DirectMessageDto> search(Long userId,Long otherUserId,String query){assertConversationParticipant(userId,otherUserId);String q=query==null?"":query.trim().toLowerCase();if(q.isBlank())return List.of();return messages.search(userId,otherUserId,q,org.springframework.data.domain.PageRequest.of(0,100)).stream().map(m->dto(m,userId)).toList();}

  @Transactional(readOnly=true)
  public Attachment attachment(Long currentUserId,Long otherUserId,Long messageId){assertConversationParticipant(currentUserId,otherUserId);DirectMessageEntity message=messages.findById(messageId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"));boolean participant=(currentUserId.equals(message.getSenderUserId())||currentUserId.equals(message.getRecipientUserId()))&&otherUserId.equals(currentUserId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId());if(!participant||message.hiddenFor(currentUserId)||message.getAttachmentKey()==null)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Attachment not found");return new Attachment(storage.load(message.getAttachmentKey()),message.getAttachmentName(),message.getAttachmentType());}

  private DirectMessageEntity participantMessage(Long userId,Long otherUserId,Long messageId){assertConversationParticipant(userId,otherUserId);DirectMessageEntity message=messages.locked(messageId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"));boolean valid=(userId.equals(message.getSenderUserId())&&otherUserId.equals(message.getRecipientUserId()))||(userId.equals(message.getRecipientUserId())&&otherUserId.equals(message.getSenderUserId()));if(!valid||message.hiddenFor(userId))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found");return message;}

  private UserEntity assertConversationParticipant(Long currentUserId,Long otherUserId){if(currentUserId.equals(otherUserId))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose another person to message");users.findById(currentUserId).orElseThrow(()->new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Current user not found"));return users.findById(otherUserId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Person not found"));}
  private List<DirectMessageDto> pageDtos(List<DirectMessageEntity> page,Long currentUserId){
    if(page.isEmpty())return List.of();
    var senderIds=page.stream().map(DirectMessageEntity::getSenderUserId).distinct().toList();
    Map<Long,UserEntity> senders=new java.util.HashMap<>();
    users.findAllById(senderIds).forEach(sender->senders.put(sender.getId(),sender));
    Map<Long,String> photos=new java.util.HashMap<>();
    profiles.findAllById(senderIds).forEach(profile->photos.put(profile.getUserId(),profile.getProfilePhoto()));
    Map<Long,DirectMessageEntity> replies=new java.util.HashMap<>();
    var replyIds=page.stream().map(DirectMessageEntity::getReplyToMessageId).filter(java.util.Objects::nonNull).distinct().toList();
    if(!replyIds.isEmpty())messages.findAllById(replyIds).forEach(reply->replies.put(reply.getId(),reply));
    Map<Long,List<com.myaaptha.domain.message.model.DirectMessageReactionEntity>> byMessage=new java.util.HashMap<>();
    reactions.findByMessageIdIn(page.stream().map(DirectMessageEntity::getId).toList()).forEach(reaction->byMessage.computeIfAbsent(reaction.getMessageId(),ignored->new java.util.ArrayList<>()).add(reaction));
    var flags=personalization.flags(currentUserId,page.stream().map(DirectMessageEntity::getId).toList());
    boolean readVisible=personalization.receiptsVisible(page.stream().flatMap(m->java.util.stream.Stream.of(m.getSenderUserId(),m.getRecipientUserId())).distinct().toList());
    return page.stream().map(message->dto(message,currentUserId,senders.get(message.getSenderUserId()),photos.get(message.getSenderUserId()),replyPreview(message,replies.get(message.getReplyToMessageId()),currentUserId),byMessage.getOrDefault(message.getId(),List.of()),flags.getOrDefault(message.getId(),MessagePersonalization.NONE),readVisible)).toList();
  }
  private String replyPreview(DirectMessageEntity message,DirectMessageEntity reply,Long user){
    if(message.getReplyToMessageId()==null)return null;
    if(reply==null||reply.hiddenFor(user))return "Message unavailable";
    return reply.getDeletedAt()!=null?"Deleted message":reply.getMessage().isBlank()?(reply.getAttachmentName()==null?"Attachment":reply.getAttachmentName()):reply.getMessage();
  }
  private DirectMessageDto dto(DirectMessageEntity message,Long currentUserId){
    var sender=users.findById(message.getSenderUserId()).orElseThrow();
    var reply=message.getReplyToMessageId()==null?null:messages.findById(message.getReplyToMessageId()).orElse(null);
    return dto(message,currentUserId,sender,photo(sender),replyPreview(message,reply,currentUserId),reactions.findByMessageId(message.getId()),personalization.flags(currentUserId,List.of(message.getId())).getOrDefault(message.getId(),MessagePersonalization.NONE),personalization.receiptsVisible(List.of(message.getSenderUserId(),message.getRecipientUserId())));
  }
  private DirectMessageDto dto(DirectMessageEntity message,Long currentUserId,UserEntity sender,String photo,String preview,List<com.myaaptha.domain.message.model.DirectMessageReactionEntity> messageReactions,MessagePersonalization.Flags flags,boolean readVisible){if(message.hiddenFor(currentUserId))return new DirectMessageDto(message.getId(),message.getSenderUserId(),message.getRecipientUserId(),"",null,"",null,null,null,null,message.getCreatedAt(),null,null,null,null,null,null,Map.of(),null,currentUserId.equals(message.getSenderUserId()),false,false,false,false,true);String name=name(sender);String attachmentUrl=message.getAttachmentKey()==null?null:"/api/network/messages/with/"+(currentUserId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId())+"/"+message.getId()+"/attachment";Map<String,Long> counts=new LinkedHashMap<>();String mine=null;for(var reaction:messageReactions){counts.merge(reaction.getEmoji(),1L,Long::sum);if(currentUserId.equals(reaction.getUserId()))mine=reaction.getEmoji();}return new DirectMessageDto(message.getId(),message.getSenderUserId(),message.getRecipientUserId(),name,photo,message.getDeletedAt()==null?message.getMessage():"",attachmentUrl,message.getAttachmentName(),message.getAttachmentType(),message.getAttachmentSize(),message.getCreatedAt(),message.getDeliveredAt(),(readVisible||currentUserId.equals(message.getRecipientUserId()))?message.getReadAt():null,message.getReplyToMessageId(),preview,message.getEditedAt(),message.getDeletedAt(),counts,mine,currentUserId.equals(message.getSenderUserId()),flags.starred(),flags.pinned(),message.isForwarded(),canDeleteForAll(message,currentUserId),false);}

  public DirectMessageDto flags(Long user,Long other,Long id,Boolean starred,Boolean pinned) {
    var message=participantMessage(user,other,id);
    if(starred==null&&pinned==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose star or pin");
    if(message.getDeletedAt()!=null&&(Boolean.TRUE.equals(starred)||Boolean.TRUE.equals(pinned)))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot be saved");
    personalization.save(user,id,starred,pinned);return dto(message,user);
  }
  @Transactional(readOnly=true)
  public List<DirectMessageDto> saved(Long user,Long other,String kind,Long before,int limit) {
    assertConversationParticipant(user,other);
    if(!Set.of("starred","pinned").contains(kind))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose starred or pinned");
    return pageDtos(messages.saved(user,other,kind,before,org.springframework.data.domain.PageRequest.of(0,pageSize(limit))),user);
  }
  public void acknowledgeRead(Long user,Long other,List<Long> ids) {
    assertConversationParticipant(user,other);
    var found=ids.stream().distinct().sorted(java.util.Comparator.reverseOrder()).map(id->messages.locked(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"))).toList();
    if(found.size()!=new java.util.HashSet<>(ids).size() || found.stream().anyMatch(m->!user.equals(m.getRecipientUserId())||!other.equals(m.getSenderUserId())||m.hiddenFor(user)))
      throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found");
    var now=Instant.now();
    for(var message:found){if(message.getDeliveredAt()==null)message.setDeliveredAt(now);if(message.getReadAt()==null)message.setReadAt(now);}
    messages.saveAll(found);
  }
  public void pinChat(Long user,Long other,boolean pinned) { assertConversationParticipant(user,other);personalization.pinChat(user,other,pinned); }
  public void chatSettings(Long user,Long other,Boolean archived,Boolean muted,Boolean markedUnread) {
    assertConversationParticipant(user,other);
    if(archived==null&&muted==null&&markedUnread==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a chat setting");
    if(messages.page(user,other,Long.MAX_VALUE,org.springframework.data.domain.PageRequest.of(0,1)).isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Conversation not found");
    personalization.saveChatSettings(user,other,archived,muted,markedUnread);
  }
  public record Attachment(Resource resource,String name,String type){}
  private int pageSize(int size){if(size<1||size>100)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Limit must be between 1 and 100");return size;}
  private String name(UserEntity user){String value=((user.getFirstName()==null?"":user.getFirstName())+" "+(user.getSurname()==null?"":user.getSurname())).trim();return value.isBlank()?user.getUsername():value;}
  private String photo(UserEntity user){return profiles.findById(user.getId()).map(profile->profile.getProfilePhoto()).orElse(null);}
}
