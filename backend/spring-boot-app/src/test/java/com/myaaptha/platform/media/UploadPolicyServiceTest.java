package com.myaaptha.platform.media;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.Instant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import org.springframework.web.server.ResponseStatusException;
class UploadPolicyServiceTest {
 final UploadPolicyService service=new UploadPolicyService(mock(JdbcTemplate.class));
 final UploadPolicyService.Level free=new UploadPolicyService.Level(1,"Free",1073741824L,26214400,36500,true);
 @AfterEach void clear(){RequestContextHolder.resetRequestAttributes();}
 void request(String path,String days){var req=new MockHttpServletRequest("POST",path);if(days!=null)req.setParameter("retentionDays",days);RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));}
 @Test void normalUploadsDefaultToNever(){assertThat(service.expiry(free)).isNull();}
 @Test void everySelectedDurationSetsItsDeadline(){for(int days:UploadPolicyService.RETENTION_DAYS){request("/api/network/messages/with/2",String.valueOf(days));var expiry=service.expiry(free);if(days==0)assertThat(expiry).isNull();else assertThat(expiry).isBetween(Instant.now().plusSeconds(days*86400L-5),Instant.now().plusSeconds(days*86400L+5));}}
 @Test void invalidDurationsAreRejected(){for(String days:new String[]{"-1","3","366","3651","abc","1.5","999999999999999999"}){request("/api/network/messages/with/2",days);assertThatThrownBy(()->service.expiry(free)).isInstanceOf(ResponseStatusException.class);}}
 @Test void statusAlwaysExpiresInOneDay(){request("/api/social/stories","0");assertThat(service.expiry(free)).isBetween(Instant.now().plusSeconds(86390),Instant.now().plusSeconds(86410));}
 @Test void olderLevelMetadataDoesNotRemoveExpiryChoices(){var finite=new UploadPolicyService.Level(2,"Limited",100,10,30,false);request("/api/network/messages/with/2","3650");assertThat(service.expiry(finite)).isAfter(Instant.now());}
 @Test void paidPlansAboveOneHundredGbAndFiniteOnlyPlansAreRejected(){
  assertThatThrownBy(()->service.save(new UploadPolicyService.Level(2,"Too large",107374182401L,10,30,true))).isInstanceOf(ResponseStatusException.class);
  assertThatThrownBy(()->service.save(new UploadPolicyService.Level(2,"Finite",100,10,30,false))).isInstanceOf(ResponseStatusException.class);
 }
 @Test void unsafeLevelConfigurationRejected(){assertThatThrownBy(()->service.save(new UploadPolicyService.Level(6,"Bad",100,26214401,30,true))).isInstanceOf(ResponseStatusException.class);}
}
