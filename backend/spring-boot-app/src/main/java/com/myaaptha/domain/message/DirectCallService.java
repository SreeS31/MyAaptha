package com.myaaptha.domain.message;

import com.myaaptha.domain.message.model.DirectCallEntity;
import com.myaaptha.domain.network.dto.DirectCallDto;
import com.myaaptha.domain.network.dto.StartDirectCallRequest;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.privacy.UserBlockRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.notification.NotificationCommand;
import com.myaaptha.domain.notification.NotificationService;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service @Transactional
public class DirectCallService {
  private final DirectCallRepository calls; private final UserRepository users; private final RelationshipRepository relationships; private final UserProfileRepository profiles; private final NotificationService notificationService; private final UserBlockRepository blocks;
  public DirectCallService(DirectCallRepository calls,UserRepository users,RelationshipRepository relationships,UserProfileRepository profiles,NotificationService notificationService,UserBlockRepository blocks){this.calls=calls;this.users=users;this.relationships=relationships;this.profiles=profiles;this.notificationService=notificationService;this.blocks=blocks;}
  public DirectCallDto start(Long callerId,StartDirectCallRequest request){if(request==null||request.recipientId()==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a person to call");if(callerId.equals(request.recipientId()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"You cannot call yourself");if(blocks.blockedEitherWay(callerId,request.recipientId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Calls are unavailable for this account");String type=request.callType()==null?"":request.callType().trim().toUpperCase();if(!Set.of("AUDIO","VIDEO").contains(type))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Call type must be audio or video");if(request.offerSdp()==null||request.offerSdp().isBlank())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Call connection offer is missing");UserEntity recipient=users.findById(request.recipientId()).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Person not found"));if(!"ACTIVE".equals(recipient.getAccountStatus())||"MANAGED".equals(recipient.getIdentityType()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"This person cannot receive calls");if(relationships.findByOwnerUserIdAndRelatedUserId(callerId,recipient.getId()).isEmpty())throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Add this person to your relationships before calling");DirectCallEntity call=new DirectCallEntity();call.setCallerUserId(callerId);call.setRecipientUserId(recipient.getId());call.setCallType(type);call.setOfferSdp(request.offerSdp());call=calls.save(call);UserEntity caller=users.findById(callerId).orElseThrow();notificationService.notify(new NotificationCommand(recipient.getId(),"CALL","Incoming "+type.toLowerCase()+" call",name(caller)+" is calling you","/dashboard?callId="+call.getId(),"DIRECT_CALL",call.getId()));return dto(call,callerId);}
  @Transactional(readOnly=true) public List<DirectCallDto> incoming(Long userId){return calls.findByRecipientUserIdAndStatusOrderByCreatedAtDesc(userId,"RINGING").stream().filter(call->call.getCreatedAt().isAfter(Instant.now().minusSeconds(90))).filter(call->!blocks.blockedEitherWay(userId,call.getCallerUserId())).map(call->dto(call,userId)).toList();}
  @Transactional(readOnly=true) public DirectCallDto get(Long userId,Long callId){return dto(participant(userId,callId),userId);}
  public DirectCallDto accept(Long userId,Long callId,String answerSdp){DirectCallEntity call=recipient(userId,callId);if(!"RINGING".equals(call.getStatus()))throw new ResponseStatusException(HttpStatus.CONFLICT,"This call is no longer ringing");if(answerSdp==null||answerSdp.isBlank())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Call connection answer is missing");call.setAnswerSdp(answerSdp);call.setStatus("ACCEPTED");call.setUpdatedAt(Instant.now());return dto(calls.save(call),userId);}
  public DirectCallDto reject(Long userId,Long callId){DirectCallEntity call=recipient(userId,callId);call.setStatus("REJECTED");call.setUpdatedAt(Instant.now());return dto(calls.save(call),userId);}
  public DirectCallDto end(Long userId,Long callId){DirectCallEntity call=participant(userId,callId);call.setStatus("ENDED");call.setUpdatedAt(Instant.now());return dto(calls.save(call),userId);}
  private DirectCallEntity participant(Long userId,Long callId){DirectCallEntity call=calls.findById(callId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Call not found"));if(!userId.equals(call.getCallerUserId())&&!userId.equals(call.getRecipientUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only call participants can access this call");return call;}
  private DirectCallEntity recipient(Long userId,Long callId){DirectCallEntity call=participant(userId,callId);if(!userId.equals(call.getRecipientUserId()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Only the recipient can answer this call");return call;}
  private DirectCallDto dto(DirectCallEntity call,Long currentUserId){UserEntity caller=users.findById(call.getCallerUserId()).orElseThrow();UserEntity recipient=users.findById(call.getRecipientUserId()).orElseThrow();return new DirectCallDto(call.getId(),caller.getId(),recipient.getId(),name(caller),photo(caller),name(recipient),photo(recipient),call.getCallType(),call.getStatus(),call.getOfferSdp(),call.getAnswerSdp(),call.getCreatedAt(),call.getUpdatedAt(),currentUserId.equals(caller.getId()));}
  private String name(UserEntity user){String result=((user.getFirstName()==null?"":user.getFirstName())+" "+(user.getSurname()==null?"":user.getSurname())).trim();return result.isBlank()?user.getUsername():result;}
  private String photo(UserEntity user){return profiles.findById(user.getId()).map(profile->profile.getProfilePhoto()).orElse(null);}
}
