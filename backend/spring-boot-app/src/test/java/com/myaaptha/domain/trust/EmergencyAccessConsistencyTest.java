package com.myaaptha.domain.trust;
import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.social.SocialPostRepository;
import com.myaaptha.domain.social.model.SocialPostEntity;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.server.ResponseStatusException;

@SpringBootTest
class EmergencyAccessConsistencyTest {
 @Autowired TrustService service;@Autowired UserRepository users;@Autowired SocialPostRepository posts;
 @Autowired EmergencyApprovalRepository approvals;
 Long member(){var u=new UserEntity();u.setUsername("emergency-consistency-"+UUID.randomUUID());u.setPasswordHash("test-only");return users.saveAndFlush(u).getId();}
 long request(Long owner,Long requester,Long approver){service.add(owner,requester,"STAR");service.add(owner,approver,"STAR");return service.request(requester,owner,"A synthetic emergency requiring access to eligible documents").id();}
 @Test void concurrentDuplicateDecisionsAreSerializedAndCapabilitiesMatchTheViewer()throws Exception{
   Long owner=member(),requester=member(),approver=member(),stranger=member();long id=request(owner,requester,approver);
   assertFalse(service.emergencyRequests(owner).stream().filter(r->r.id()==id).findFirst().orElseThrow().canDecide());
   assertFalse(service.emergencyRequests(requester).stream().filter(r->r.id()==id).findFirst().orElseThrow().canDecide());
   assertTrue(service.emergencyRequests(approver).stream().filter(r->r.id()==id).findFirst().orElseThrow().canDecide());
   var ready=new CountDownLatch(2);var start=new CountDownLatch(1);
   try(var pool=Executors.newFixedThreadPool(2)){
     Callable<String> decision=()->{ready.countDown();start.await();try{return service.decide(approver,id,true).status();}catch(ResponseStatusException e){return "HTTP_"+e.getStatusCode().value();}};
     var first=pool.submit(decision);var second=pool.submit(decision);assertTrue(ready.await(5,TimeUnit.SECONDS));start.countDown();
     assertEquals(Set.of("APPROVED","HTTP_400"),new HashSet<>(List.of(first.get(20,TimeUnit.SECONDS),second.get(20,TimeUnit.SECONDS))));
   }
   assertEquals(2,approvals.countByRequestIdAndApprovedTrue(id));
   assertTrue(service.emergencyRequests(requester).stream().filter(r->r.id()==id).findFirst().orElseThrow().canViewDocuments());
   assertFalse(service.emergencyRequests(approver).stream().filter(r->r.id()==id).findFirst().orElseThrow().canViewDocuments());
   assertFalse(service.emergencyRequests(owner).stream().filter(r->r.id()==id).findFirst().orElseThrow().canViewDocuments());
   assertTrue(service.emergencyRequests(stranger).isEmpty());
 }
 @Test void eligibleOwnerDocumentsAreFilteredBeforeTheGlobalLimitAndRevokedRequesterCannotOpen(){
   Long owner=member(),requester=member(),approver=member(),other=member();long id=request(owner,requester,approver);service.decide(approver,id,true);
   var own=new SocialPostEntity();own.setAuthorUserId(owner);own.setCaption("Owner fixture");own.setAudience("PRIVATE");own.setMediaKey("fixture-owner.pdf");own.setMediaName("owner.pdf");own.setMediaType("application/pdf");own=posts.saveAndFlush(own);long document=own.getId();
   var noise=new ArrayList<SocialPostEntity>();for(int i=0;i<105;i++){var p=new SocialPostEntity();p.setAuthorUserId(other);p.setAudience("PRIVATE");p.setMediaKey("fixture-other-"+i+".pdf");p.setMediaName("other.pdf");p.setMediaType("application/pdf");noise.add(p);}posts.saveAllAndFlush(noise);
   assertTrue(service.documents(requester,id).stream().anyMatch(d->d.id()==document));
   assertThrows(ResponseStatusException.class,()->service.documents(other,id));
   service.remove(owner,requester,"STAR");
   assertThrows(ResponseStatusException.class,()->service.documents(requester,id));
   assertFalse(service.emergencyRequests(requester).stream().filter(r->r.id()==id).findFirst().orElseThrow().canViewDocuments());
 }
}
