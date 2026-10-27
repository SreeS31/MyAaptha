package com.myaaptha.domain;

import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.user.*;
import com.myaaptha.domain.user.model.*;
import com.myaaptha.domain.message.*;
import com.myaaptha.domain.message.model.*;
import com.myaaptha.domain.circle.*;
import com.myaaptha.domain.circle.model.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.PageRequest;

@SpringBootTest @Transactional
class ScalingQueryTest {
  @Autowired DirectCallRepository calls;
  @Autowired UserRepository users;
  @Autowired DirectMessageRepository messages;
  @Autowired DirectMessageService direct;
  @Autowired CircleRepository circles;
  @Autowired CirclePostRepository posts;
  @Autowired CircleConversationService conversation;
  private Long user(){var u=new UserEntity();u.setUsername("scale-"+java.util.UUID.randomUUID());u.setPasswordHash("test-only");return users.save(u).getId();}
  @Test void messagePagesCoverHistoryAndReadRequiresAcknowledgement(){
    Long first=user(),second=user(),outsider=user();
    for(int i=0;i<123;i++){var m=new DirectMessageEntity();m.setSenderUserId(first);m.setRecipientUserId(second);m.setMessage("history "+i);messages.save(m);}
    var unrelated=new DirectMessageEntity();unrelated.setSenderUserId(first);unrelated.setRecipientUserId(outsider);unrelated.setMessage("private");messages.saveAndFlush(unrelated);
    var newest=direct.conversation(second,first);assertEquals(50,newest.size());
    var earlier=direct.conversation(second,first,newest.getFirst().id(),50);assertEquals(50,earlier.size());
    assertTrue(earlier.getLast().id()<newest.getFirst().id());
    var oldest=direct.conversation(second,first,earlier.getFirst().id(),50);assertEquals(23,oldest.size());
    assertEquals(2,messages.latestConversations(first).size());
    assertEquals(123L,messages.unreadCounts(second).getFirst().getUnreadCount());
    direct.acknowledgeRead(second,first,newest.stream().map(com.myaaptha.domain.network.dto.DirectMessageDto::id).toList());
    assertEquals(73L,messages.unreadCounts(second).getFirst().getUnreadCount());
    direct.acknowledgeRead(second,first,earlier.stream().map(com.myaaptha.domain.network.dto.DirectMessageDto::id).toList());
    direct.acknowledgeRead(second,first,oldest.stream().map(com.myaaptha.domain.network.dto.DirectMessageDto::id).toList());
    assertTrue(messages.unreadCounts(second).isEmpty());
    assertThrows(org.springframework.web.server.ResponseStatusException.class,()->direct.conversation(first,second,Long.MAX_VALUE,101));
  }
  @Test void circleAggregateIsMemberScopedAndCountsOnlyUnreadPosts(){
    Long first=user(),second=user(),outsider=user();var c=new CircleEntity();c.setName("scale-"+java.util.UUID.randomUUID());c.setDescription("test");c.setOwnerUserId(first);c.getMemberUserIds().add(first);c.getMemberUserIds().add(second);c=circles.saveAndFlush(c);
    for(int i=0;i<63;i++){var p=new CirclePostEntity();p.setCircleId(c.getId());p.setAuthorUserId(first);p.setMessage("history "+i);posts.save(p);}posts.flush();
    assertEquals(63L,conversation.unreadCounts(second).get(c.getId()));
    assertTrue(conversation.unreadCounts(outsider).isEmpty());
    var page=conversation.posts(second,c.getId());assertEquals(50,page.size());
    assertTrue(page.stream().allMatch(post->post.readCount()==1));
    assertEquals(13L,conversation.unreadCounts(second).get(c.getId()));
    assertEquals(13,conversation.posts(second,c.getId(),page.getFirst().id(),50).size());
    assertEquals(0L,conversation.unreadCounts(second).get(c.getId()));
  }
  @Test void circleDirectoryIncludesOwnerAndMembersWithoutDuplicatesOrOutsiders(){
    Long owner=user(),member=user(),outsider=user();var c=new CircleEntity();c.setName("directory");c.setDescription("private");c.setOwnerUserId(owner);c.getMemberUserIds().add(owner);c.getMemberUserIds().add(member);circles.saveAndFlush(c);
    assertEquals(1,circles.findVisibleToUser(owner).size());assertEquals(1,circles.findVisibleToUser(member).size());assertTrue(circles.findVisibleToUser(outsider).isEmpty());
  }
  @Test void incomingCallsExcludeExpiredAndOtherRecipientsInTheDatabase(){
    Long caller=user(),recipient=user(),other=user();
    var cutoff=java.time.Instant.now().minusSeconds(90);
    for(int i=0;i<4;i++){
      var call=new DirectCallEntity();call.setCallerUserId(caller);
      call.setRecipientUserId(i==3?other:recipient);call.setCallType("AUDIO");call.setOfferSdp("synthetic");
      if(i==0)org.springframework.test.util.ReflectionTestUtils.setField(call,"createdAt",cutoff.minusSeconds(1));
      if(i==2)call.setStatus("ENDED");
      calls.save(call);
    }
    calls.flush();
    var visible=calls.findByRecipientUserIdAndStatusAndCreatedAtAfterOrderByCreatedAtDesc(recipient,"RINGING",cutoff);
    assertEquals(1,visible.size());assertEquals(recipient,visible.getFirst().getRecipientUserId());
    assertTrue(visible.getFirst().getCreatedAt().isAfter(cutoff));
  }

}
