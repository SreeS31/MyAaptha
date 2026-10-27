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
 @Test void selectedDaysSetExpiry(){request("/api/network/messages/with/2","7");assertThat(service.expiry(free)).isBetween(Instant.now().plusSeconds(604790),Instant.now().plusSeconds(604810));}
 @Test void statusAlwaysExpiresInOneDay(){request("/api/social/stories","0");assertThat(service.expiry(free)).isBetween(Instant.now().plusSeconds(86390),Instant.now().plusSeconds(86410));}
 @Test void finitePolicyRejectsNeverAndExcessiveRetention(){var finite=new UploadPolicyService.Level(2,"Limited",100,10,30,false);for(String value:new String[]{"0","31","-1","abc"}){request("/api/network/messages/with/2",value);assertThatThrownBy(()->service.expiry(finite)).isInstanceOf(ResponseStatusException.class);}request("/api/network/messages/with/2",null);assertThat(service.expiry(finite)).isAfter(Instant.now());}
 @Test void unsafeLevelConfigurationRejected(){assertThatThrownBy(()->service.save(new UploadPolicyService.Level(6,"Bad",100,26214401,30,true))).isInstanceOf(ResponseStatusException.class);}
}
