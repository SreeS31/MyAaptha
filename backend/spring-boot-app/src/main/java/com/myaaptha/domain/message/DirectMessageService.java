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
  private static final Set<String> ALLOWED_REACTIONS=Set.of("👍","❤️","😂","😮","😢","🙏");
  public DirectMessageService(DirectMessageRepository messages,UserRepository users,RelationshipRepository relationships,UserProfileRepository profiles,CircleMediaStorage storage,NotificationService notificationService,UserBlockRepository blocks,DirectMessageReactionRepository reactions){this.messages=messages;this.users=users;this.relationships=relationships;this.profiles=profiles;this.storage=storage;this.notificationService=notificationService;this.blocks=blocks;this.reactions=reactions;}

  public List<DirectMessageDto> conversation(Long currentUserId,Long otherUserId){assertConversationParticipant(currentUserId,otherUserId);var conversation=messages.conversation(currentUserId,otherUserId);var now=java.time.Instant.now();conversation.stream().filter(message->currentUserId.equals(message.getRecipientUserId())&&message.getReadAt()==null).forEach(message->{if(message.getDeliveredAt()==null)message.setDeliveredAt(now);message.setReadAt(now);});messages.saveAll(conversation);return conversation.stream().map(message->dto(message,currentUserId)).toList();}

  @Transactional(readOnly=true) public List<DirectConversationDto> conversations(Long userId){users.findById(userId).orElseThrow();var all=messages.findBySenderUserIdOrRecipientUserIdOrderByCreatedAtDescIdDesc(userId,userId);Map<Long,DirectMessageEntity> latest=new LinkedHashMap<>();Map<Long,Long> unread=new java.util.HashMap<>();for(var message:all){Long other=userId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId();latest.putIfAbsent(other,message);if(userId.equals(message.getRecipientUserId())&&message.getReadAt()==null)unread.merge(other,1L,Long::sum);}return latest.entrySet().stream().map(entry->{UserEntity other=users.findById(entry.getKey()).orElseThrow();DirectMessageEntity message=entry.getValue();String preview=message.getDeletedAt()!=null?"Message deleted":message.getMessage()!=null&&!message.getMessage().isBlank()?message.getMessage():message.getAttachmentName()!=null?message.getAttachmentName():"Attachment";return new DirectConversationDto(other.getId(),name(other),photo(other),preview,message.getCreatedAt(),unread.getOrDefault(other.getId(),0L));}).toList();}

  public DirectMessageDto send(Long senderId,Long recipientId,String message,MultipartFile file,Long replyToMessageId){
    UserEntity recipient=assertConversationParticipant(senderId,recipientId);
    if(blocks.blockedEitherWay(senderId,recipientId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Messaging is unavailable for this account");
    if(!"ACTIVE".equals(recipient.getAccountStatus())||"MANAGED".equals(recipient.getIdentityType()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"This person does not have an active MyAaptha account and cannot receive private messages");
    if(relationships.findByOwnerUserIdAndRelatedUserId(senderId,recipientId).isEmpty()&&messages.conversation(senderId,recipientId).isEmpty())throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Add this person to your relationships before sending a private message");
    String clean=message==null?"":message.trim();
    if(clean.length()>4000)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Message must be 4000 characters or less");
    if(clean.isBlank()&&(file==null||file.isEmpty()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Write a message or choose a file");
    DirectMessageEntity directMessage=new DirectMessageEntity();directMessage.setSenderUserId(senderId);directMessage.setRecipientUserId(recipientId);directMessage.setMessage(clean);directMessage.setDeliveredAt(java.time.Instant.now());
    if(replyToMessageId!=null){DirectMessageEntity reply=participantMessage(senderId,recipientId,replyToMessageId);if(reply.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"The replied message was deleted");directMessage.setReplyToMessageId(replyToMessageId);}
    if(file!=null&&!file.isEmpty()){var media=storage.store(senderId,file);directMessage.setAttachmentKey(media.key());directMessage.setAttachmentName(media.name());directMessage.setAttachmentType(media.type());directMessage.setAttachmentSize(media.size());}
    DirectMessageEntity saved=messages.save(directMessage); UserEntity sender=users.findById(senderId).orElseThrow();
    notificationService.notify(new NotificationCommand(recipientId,"DIRECT_MESSAGE","New message from "+name(sender),clean.isBlank()?"Sent an attachment":clean,"/dashboard?messageUserId="+senderId,"DIRECT_MESSAGE",saved.getId()));
    return dto(saved,senderId);
  }
  public DirectMessageDto send(Long senderId,Long recipientId,String message,MultipartFile file){return send(senderId,recipientId,message,file,null);}

  public DirectMessageDto edit(Long userId,Long otherUserId,Long messageId,String value){DirectMessageEntity message=participantMessage(userId,otherUserId,messageId);if(!userId.equals(message.getSenderUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only the sender can edit this message");if(message.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot be edited");String clean=value==null?"":value.trim();if(clean.length()>4000)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Message must be 4000 characters or less");if(clean.isBlank()&&message.getAttachmentKey()==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"A message cannot be empty");message.setMessage(clean);message.setEditedAt(Instant.now());return dto(messages.save(message),userId);}
  public DirectMessageDto delete(Long userId,Long otherUserId,Long messageId){DirectMessageEntity message=participantMessage(userId,otherUserId,messageId);if(!userId.equals(message.getSenderUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only the sender can delete this message");if(message.getDeletedAt()==null){if(message.getAttachmentKey()!=null)storage.delete(message.getAttachmentKey());message.setAttachmentKey(null);message.setAttachmentName(null);message.setAttachmentType(null);message.setAttachmentSize(null);message.setMessage("");message.setDeletedAt(Instant.now());}return dto(messages.save(message),userId);}
  public DirectMessageDto react(Long userId,Long otherUserId,Long messageId,String emoji){if(blocks.blockedEitherWay(userId,otherUserId))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Messaging is unavailable for this account");DirectMessageEntity message=participantMessage(userId,otherUserId,messageId);if(message.getDeletedAt()!=null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Deleted messages cannot receive reactions");String clean=emoji==null?"":emoji.trim();if(!clean.isEmpty()&&!ALLOWED_REACTIONS.contains(clean))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a supported reaction");var existing=reactions.findByMessageIdAndUserId(messageId,userId);if(clean.isEmpty())existing.ifPresent(reactions::delete);else if(existing.isPresent()){existing.get().setEmoji(clean);reactions.save(existing.get());}else{var reaction=new com.myaaptha.domain.message.model.DirectMessageReactionEntity();reaction.setMessageId(messageId);reaction.setUserId(userId);reaction.setEmoji(clean);reactions.save(reaction);}return dto(message,userId);}
  @Transactional(readOnly=true) public List<DirectMessageDto> search(Long userId,Long otherUserId,String query){assertConversationParticipant(userId,otherUserId);String q=query==null?"":query.trim().toLowerCase();if(q.isBlank())return List.of();return messages.conversation(userId,otherUserId).stream().filter(m->m.getDeletedAt()==null&&((m.getMessage()!=null&&m.getMessage().toLowerCase().contains(q))||(m.getAttachmentName()!=null&&m.getAttachmentName().toLowerCase().contains(q)))).map(m->dto(m,userId)).toList();}

  @Transactional(readOnly=true)
  public Attachment attachment(Long currentUserId,Long otherUserId,Long messageId){assertConversationParticipant(currentUserId,otherUserId);DirectMessageEntity message=messages.findById(messageId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"));boolean participant=(currentUserId.equals(message.getSenderUserId())||currentUserId.equals(message.getRecipientUserId()))&&otherUserId.equals(currentUserId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId());if(!participant||message.getAttachmentKey()==null)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Attachment not found");return new Attachment(storage.load(message.getAttachmentKey()),message.getAttachmentName(),message.getAttachmentType());}

  private DirectMessageEntity participantMessage(Long userId,Long otherUserId,Long messageId){assertConversationParticipant(userId,otherUserId);DirectMessageEntity message=messages.findById(messageId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found"));boolean valid=(userId.equals(message.getSenderUserId())&&otherUserId.equals(message.getRecipientUserId()))||(userId.equals(message.getRecipientUserId())&&otherUserId.equals(message.getSenderUserId()));if(!valid)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Message not found");return message;}

  private UserEntity assertConversationParticipant(Long currentUserId,Long otherUserId){if(currentUserId.equals(otherUserId))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose another person to message");users.findById(currentUserId).orElseThrow(()->new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Current user not found"));return users.findById(otherUserId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Person not found"));}
  private DirectMessageDto dto(DirectMessageEntity message,Long currentUserId){UserEntity sender=users.findById(message.getSenderUserId()).orElseThrow();String name=((sender.getFirstName()==null?"":sender.getFirstName())+" "+(sender.getSurname()==null?"":sender.getSurname())).trim();if(name.isBlank())name=sender.getUsername();String photo=profiles.findById(sender.getId()).map(profile->profile.getProfilePhoto()).orElse(null);String attachmentUrl=message.getAttachmentKey()==null?null:"/api/network/messages/with/"+(currentUserId.equals(message.getSenderUserId())?message.getRecipientUserId():message.getSenderUserId())+"/"+message.getId()+"/attachment";String preview=message.getReplyToMessageId()==null?null:messages.findById(message.getReplyToMessageId()).map(m->m.getDeletedAt()!=null?"Deleted message":m.getMessage().isBlank()?(m.getAttachmentName()==null?"Attachment":m.getAttachmentName()):m.getMessage()).orElse("Message unavailable");Map<String,Long> counts=new LinkedHashMap<>();String mine=null;for(var reaction:reactions.findByMessageId(message.getId())){counts.merge(reaction.getEmoji(),1L,Long::sum);if(currentUserId.equals(reaction.getUserId()))mine=reaction.getEmoji();}return new DirectMessageDto(message.getId(),message.getSenderUserId(),message.getRecipientUserId(),name,photo,message.getDeletedAt()==null?message.getMessage():"",attachmentUrl,message.getAttachmentName(),message.getAttachmentType(),message.getAttachmentSize(),message.getCreatedAt(),message.getDeliveredAt(),message.getReadAt(),message.getReplyToMessageId(),preview,message.getEditedAt(),message.getDeletedAt(),counts,mine,currentUserId.equals(message.getSenderUserId()));}
  public record Attachment(Resource resource,String name,String type){}
  private String name(UserEntity user){String value=((user.getFirstName()==null?"":user.getFirstName())+" "+(user.getSurname()==null?"":user.getSurname())).trim();return value.isBlank()?user.getUsername():value;}
  private String photo(UserEntity user){return profiles.findById(user.getId()).map(profile->profile.getProfilePhoto()).orElse(null);}
}
