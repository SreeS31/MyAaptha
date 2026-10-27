package com.myaaptha.domain.message;
import java.security.Principal;
import java.time.Instant;
import java.util.*;
import jakarta.persistence.EntityManager;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import com.myaaptha.domain.message.model.DirectMessageEntity;
import com.myaaptha.domain.circle.model.CirclePostEntity;
import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.*;
@RestController @RequestMapping("/api/network/chats")
public class ChatDiscoveryController {
 private final EntityManager em;private final NetworkService network;private final UserRepository users;private final CircleRepository circles;
 public ChatDiscoveryController(EntityManager em,NetworkService network,UserRepository users,CircleRepository circles){this.em=em;this.network=network;this.users=users;this.circles=circles;}
 public record Group(@NotBlank @Size(max=100) String name,@NotNull @Size(max=100) List<@NotNull @Positive Long> memberIds){}
 @PostMapping("/groups") @Transactional public NetworkCircleDto group(Principal principal,@Valid @RequestBody Group group){
  long user=Long.parseLong(principal.getName());var created=network.createCircle(user,new CreateNetworkCircleRequest(group.name(),"Group conversation"));
  for(long member:new LinkedHashSet<>(group.memberIds()))if(member!=user)network.addCircleMember(user,created.id(),member);
  return created;
 }
 public record Hit(String type,long conversationId,long messageId,String name,String text,Instant createdAt){}
 @GetMapping("/search") @Transactional(readOnly=true) public List<Hit> search(Principal principal,@RequestParam String q){
  String query=q.trim().toLowerCase(Locale.ROOT);if(query.length()<2)return List.of();if(query.length()>100)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Search must be 100 characters or fewer");long user=Long.parseLong(principal.getName());
  var direct=em.createQuery("select m from DirectMessageEntity m where ((m.senderUserId=:u and m.senderHidden=false) or (m.recipientUserId=:u and m.recipientHidden=false)) and m.deletedAt is null and not exists (select b.id from UserBlockEntity b where (b.blockerUserId=m.senderUserId and b.blockedUserId=m.recipientUserId) or (b.blockerUserId=m.recipientUserId and b.blockedUserId=m.senderUserId)) and (locate(:q,lower(m.message))>0 or locate(:q,lower(m.attachmentName))>0) order by m.createdAt desc,m.id desc",DirectMessageEntity.class).setParameter("u",user).setParameter("q",query).setMaxResults(50).getResultList();
  var groups=em.createQuery("select p from CirclePostEntity p where p.deletedAt is null and :u not member of p.hiddenForUsers and exists (select c.id from CircleEntity c where c.id=p.circleId and :u member of c.memberUserIds) and (locate(:q,lower(p.message))>0 or locate(:q,lower(p.attachmentName))>0) order by p.createdAt desc,p.id desc",CirclePostEntity.class).setParameter("u",user).setParameter("q",query).setMaxResults(50).getResultList();
  var names=new HashMap<Long,String>();users.findAllById(direct.stream().map(m->m.getSenderUserId()==user?m.getRecipientUserId():m.getSenderUserId()).toList()).forEach(u->{String name=((u.getFirstName()==null?"":u.getFirstName())+" "+(u.getSurname()==null?"":u.getSurname())).trim();names.put(u.getId(),name.isBlank()?u.getUsername():name);});
  var groupNames=new HashMap<Long,String>();circles.findAllById(groups.stream().map(CirclePostEntity::getCircleId).toList()).forEach(c->groupNames.put(c.getId(),c.getName()));
  var result=new ArrayList<Hit>();direct.forEach(m->{long other=m.getSenderUserId()==user?m.getRecipientUserId():m.getSenderUserId();result.add(new Hit("DIRECT",other,m.getId(),names.get(other),preview(m.getMessage(),m.getAttachmentName()),m.getCreatedAt()));});groups.forEach(m->result.add(new Hit("CIRCLE",m.getCircleId(),m.getId(),groupNames.get(m.getCircleId()),preview(m.getMessage(),m.getAttachmentName()),m.getCreatedAt())));
  return result.stream().sorted(Comparator.comparing(Hit::createdAt).reversed()).limit(50).toList();
 }
 private String preview(String text,String file){String value=text==null||text.isBlank()?Objects.requireNonNullElse(file,"Attachment"):text;return value.substring(0,Math.min(240,value.length()));}
}
